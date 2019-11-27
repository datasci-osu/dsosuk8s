#!/bin/bash

# Still TODO: stage a sourced_by_bashrcs in $ADMIN_HOME_DIR, add a source of it to all .bashrc files by default, allowing instructor control of environment customizations, 

set -e

echo "Checking for nfs mount request"

# if an NFS mount is being specified for /home...
if [[ ! -z $NFS_SVC ]]; then
  # the container starts with only the user jovyan (UID 1000) and group users (GID 100)
  # we start by creating an admin-level user and group (user may not be necessary, group is)
  # still TODO: get dsadmins group added to users logging in if they are jupyterhub admins (controlled by jupyterhub seperately)
  addgroup --gid 101 dsadmins
  adduser --no-create-home --uid 1001 --gid 101 --disabled-password --disabled-login --gecos "" dsadmin
  adduser dsadmin users
  
  # move things to /tmp to work on since we'll be NFS mounting over /home
  # make a copy of the jovyan home to $NB_USER HOME
  mv /home/jovyan /tmp/jovyan                                    
  cp -r /tmp/jovyan /tmp/$NB_USER                                # keep a token jovyan around for debugging/testing
  
  # mount the NFS, soft mount in case the server hiccups (to prevent user pods from going zombie), but 10 second timeout to prevent potential issues (based on recs for EFS, which I'd guess generalize? https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-nfs-mount-settings.html)
  mount -o soft,timeo=100 $NFS_SVC:/ /home
  #rm -rf /home/jovyan /home/$NB_USER /home/admin_config            # just for debugging, clean out previous writes and start fresh 

  # set UID to psuedorandom number in range 2000 -- 2^30 using some bash and modulus tricks
  # TODO: use a scheme that picks a random number not in use within $ADMIN_HOME_DIR/automanaged/etc_passwd_additions (below) to avoid UID collisions
  BIG=1073741824
  PSEUDO=$(md5sum <<< "$NB_USER")
  NB_UID=$(( (((0x${PSEUDO%% *} % $BIG) + $BIG) % $BIG) + 2000))

  ## now we need to setup permissions properly, and copy results to the /home mount
  ## Do so *only* if they don't already exist in /home, so this happens only at first login (otherwise every login would result in cleaned out home dirs)

  # leave a debug jovyan around for kubernetes testing: kubectl exec -it pod/singleuser-pod bash has built-in hooks that look for /home/jovyan and fail if it's not there
  # TODO: in the future we could allow a jovyan login (with password set during spinup) for a dummy student account - instructors like dummy student accounts to test things with
  if [[ ! -d /home/jovyan ]]; then
    # these permissions and ownership set things up nicely for class usage - instructors mostly all powerful (file permission-wise), students normally-powerful
    chown 1000:dsadmins /tmp/jovyan
    chmod -R 770 /tmp/jovyan                        # make sure we have group read on everything, some aren't in the .npm cache dir
    # re-own inner contents
    chown -R 1000:100 /tmp/jovyan/.??*                        # chown dotfiles, TODO: won't work with .a or other single-letter dotfiles
    chown -R 1000:100 /tmp/jovyan/*                           # chown others
    echo 'unset XDG_RUNTIME_DIR' >> /tmp/jovyan/.bashrc       # this junk: https://github.com/jupyter/notebook/issues/1318

    cp -a /tmp/jovyan /home       # copy em over to the /home mount, -a for archive (like cp -r and preserve ownership and other metadata)
  fi

  # all done - remove /tmp staging  
  rm -rf /tmp/jovyan            # clean up /tmp staging

  # same thing as above, for the actual user (TODO: split various parts of this script out, reduce redundancy)
  if [[ ! -d /home/$NB_USER ]]; then
    chown $NB_UID:dsadmins /tmp/$NB_USER 
    chmod -R 770 /tmp/$NB_USER                      
    
    chown -R $NB_UID:100 /tmp/$NB_USER/.??* 
    chown -R $NB_UID:100 /tmp/$NB_USER/* 
    
    echo 'unset XDG_RUNTIME_DIR' >> /tmp/$NB_USER/.bashrc 
  
    cp -a /tmp/$NB_USER /home
  fi
    
  rm -rf /tmp/$NB_USER


  ## We need a place in the /home mount to store info that we'd like to add to /etc/passwd, 
  ## so UIDs can be mapped to usernames for file listing etc.
  ## (and other persistent admin-level config related to the /home mount)

  # if no setting for location for config info, set one
  if [[ -z $ADMIN_HOME_DIR ]]; then
    ADMIN_HOME_DIR=/home/admin_config
  fi

  # if the dir doesn't exist, create it, write permissions only for admins, just read for others (to source/read things from there, but not cd and look around)
  if [[ ! -d $ADMIN_HOME_DIR ]]; then
    mkdir -p $ADMIN_HOME_DIR/automanaged
    chown -R dsadmin:dsadmins $ADMIN_HOME_DIR
    chmod -R 774 $ADMIN_HOME_DIR
  fi

  # if a class-specific /etc/passwd entry doesn't exist, add it
  # here's where entries for /etc/passwd will be appended; but we can't put them directly in /etc/passwd because changes there don't 
  # persist
  # TODO: if lots of people log in for the first time simultaneously, will the NFS be able handle the simultaneous appends? if not some sort of central service to handle this could be setup...
  if ! grep -E "^$NB_USER:" $ADMIN_HOME_DIR/automanaged/etc_passwd_additions; then
    echo "$NB_USER:x:$NB_UID:100:,,,:/home/$NB_USER:/bin/bash" >> $ADMIN_HOME_DIR/automanaged/etc_passwd_additions
  fi

  # add entries from the persisted etc_passwd_additions to the container /etc/passwd
  cat $ADMIN_HOME_DIR/automanaged/etc_passwd_additions >> /etc/passwd

  # set umask (defaulting to rw-rw---- for files and  rwxrwx--- for dirs, so that new files are by 
  # default read/write by 
  # NB_USER:users; thus the group and user are set appropriately, but they are writable by anyone
  # in the users group - including admin users. Trick is, only the owner and anyone in dsadmins
  # can access inside home dir itself, because that is owned by NB_USER:dsadmins rwxrwx---)
  echo "Defaults umask=007" >> /etc/sudoers
  # allow sudo to use this more permissive umasks than the default of union (for use by user jupyter process which is run with sudo -u $NB_USER)
  echo "Defaults umask_override" >> /etc/sudoers 

  # go the new dir rather than leaving CWD to be the no-longer existing original
  cd /home/$NB_USER
fi


