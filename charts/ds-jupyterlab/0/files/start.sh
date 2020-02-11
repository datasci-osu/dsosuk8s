#!/bin/bash

## TODO: although this script is broken into functions, it may as well not be - all these variables are global and need to be set in 
## a specific order (spaghetti!), the functions are just use for thematic grouping

set -e


add_admin_group() {
  # the container starts with only the user jovyan (UID 1000) and group users (GID 100)
  # we start by creating an admin-level user and group (user may not be necessary, group is)
  export ADMIN_USERNAME=dsadmin
  export ADMIN_GROUPNAME=dsadmins
  export USER_GROUPNAME=dsusers
  export ADMIN_GID=101
  export USER_GID=102
  export ADMIN_UID=1001
  
  addgroup --gid $ADMIN_GID $ADMIN_GROUPNAME
  addgroup --gid $USER_GID $USER_GROUPNAME
  adduser --no-create-home --uid $ADMIN_UID --gid $ADMIN_GID --disabled-password --disabled-login --gecos "" $ADMIN_USERNAME
  adduser $ADMIN_USERNAME users
}


stage_home_copies() {
  # move things to /tmp to work on since we'll be NFS mounting over /home
  # make a copy of the jovyan home to $NB_USER HOME
  echo "copying /home/jovyan to /tmp/jovyan"
  mv /home/jovyan /tmp/jovyan               
  echo "copying /tmp/jovyan to /tmp/$NB_USER"  
  cp -r /tmp/jovyan /tmp/$NB_USER                                # keep a token jovyan around for debugging/testing
  echo "done copying home dirs..."
}


do_mount() {
  # mount the NFS, soft mount in case the server hiccups (to prevent user pods from going zombie), but 10 second timeout to prevent potential issues (based on recs for EFS, which I'd guess generalize? https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-nfs-mount-settings.html)
  echo "mounting $NFS_SVC_HOME"
  mount -o soft,timeo=100 $NFS_SVC_HOME:/ /home
  echo "done mounting..."
}


set_uid() {
  # set user's UID to psuedorandom number in range 2000 -- 2^30 using some bash and modulus tricks

  # TODO: use a scheme that picks a random number not in use within $ADMIN_HOME_DIR/automanaged/etc_passwd_additions (below) to avoid UID collisions, incredibly rare though they may be
  # Since UID assignment is persisted in the mount, this should stay with the user even if they are removed+re-added within the hub.
  BIG=1073741824
  PSEUDO=$(md5sum <<< "$NB_USER")
  NB_UID=$(( (((0x${PSEUDO%% *} % $BIG) + $BIG) % $BIG) + 2000))
}


check_admin_config() {
  ## We need a place in the /home mount to store info that we'd like to add to /etc/passwd, 
  ## so UIDs can be mapped to usernames for file listing etc.
  ## (and other persistent admin-level config related to the /home mount)
  
  # if no setting for location for config info, set one
  if [[ -z $ADMIN_HOME_DIR ]]; then
    export ADMIN_HOME_DIR=/home/hub_local
  fi
  if [[ -z $DATA_HOME_DIR ]]; then
    export DATA_HOME_DIR=/home/hub_data_share
  fi
  
  
  # if the dir doesn't exist, create it, write permissions only for admins
  if [[ ! -d $ADMIN_HOME_DIR ]] ; then
    mkdir -p $ADMIN_HOME_DIR
    echo "This directory is used for hub-wide environment configuration, package and script installs, etc. It is read/writable by those in the admins group, but only readable by others." > $ADMIN_HOME_DIR/README.txt
    chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR
    chmod -R 775 $ADMIN_HOME_DIR
    chmod 664 $ADMIN_HOME_DIR/README.txt
  fi
  
  # other dirs...
  if [[ ! -d $ADMIN_HOME_DIR/automanaged ]] ; then
    mkdir -p $ADMIN_HOME_DIR/automanaged
    echo "This dir managed continuously by hub login processes, please don't edit." > $ADMIN_HOME_DIR/automanaged/README.txt
    touch $ADMIN_HOME_DIR/automanaged/etc_group_admins
    touch $ADMIN_HOME_DIR/automanaged/etc_group_users
    chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/automanaged
    chmod -R 775 $ADMIN_HOME_DIR/automanaged
    chmod 664 $ADMIN_HOME_DIR/automanaged/README.txt $ADMIN_HOME_DIR/automanaged/etc_group_users $ADMIN_HOME_DIR/automanaged/etc_group_admins
  fi
  
  if [[ ! -d $ADMIN_HOME_DIR/bin ]] ; then
    mkdir -p $ADMIN_HOME_DIR/bin
    cp -L /usr/local/bin/various/hubpip $ADMIN_HOME_DIR/bin/hubpip
    echo "This dir is automatically added to everyone's $PATH via the hubrc file" > $ADMIN_HOME_DIR/bin/README.txt
    chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/bin
    chmod -R 775 $ADMIN_HOME_DIR/bin
    chmod 664 $ADMIN_HOME_DIR/bin/README.txt
  fi

  if [[ ! -d $DATA_HOME_DIR ]] ; then
    mkdir -p $DATA_HOME_DIR
    echo "This is a good location to store datasets, it is by default only writable by admins." > $DATA_HOME_DIR/README.txt
    chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $DATA_HOME_DIR
    chmod -R 775 $DATA_HOME_DIR
    chmod 664 $DATA_HOME_DIR/README.txt
  fi
  
  if [[ ! -f $ADMIN_HOME_DIR/hubrc ]] ; then
    cp -L /usr/local/bin/various/hubrc $ADMIN_HOME_DIR/hubrc
    chown $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/hubrc
    chmod 664 $ADMIN_HOME_DIR/hubrc
  fi
  
  PYTHONVERSION=`python -c 'import sys; v = sys.version_info; print("python" + str(v[0]) + "." + str(v[1]))'`
  if [[ ! -d $ADMIN_HOME_DIR/python_libs/lib/$PYTHONVERSION/site-packages ]] ; then
    mkdir -p $ADMIN_HOME_DIR/python_libs/lib/$PYTHONVERSION/site-packages
    echo "Hub-wide python packages can be installed here, but note that you must use $ADMIN_HOME_DIR/bin/hubpip to make the installations work properly." > $ADMIN_HOME_DIR/python_libs/README.txt
    chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/python_libs
    chmod -R 775 $ADMIN_HOME_DIR/python_libs
    chmod 664 $ADMIN_HOME_DIR/python_libs/README.txt
  fi
   
  if [[ ! -f $ADMIN_HOME_DIR/autoexec_by_python_notebooks.py ]] ; then
    cp -L /usr/local/bin/various/autoexec_by_python_notebooks.py $ADMIN_HOME_DIR/autoexec_by_python_notebooks.py
    chown $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/autoexec_by_python_notebooks.py
    chmod 664 $ADMIN_HOME_DIR/autoexec_by_python_notebooks.py
  fi

  # if a class-specific /etc/passwd entry doesn't exist, add it
  # here's where entries for /etc/passwd will be appended; but we can't put them directly in /etc/passwd because changes there don't 
  # persist
  if ! grep -E "^$NB_USER:" $ADMIN_HOME_DIR/automanaged/etc_passwd_additions; then
    # if lots of people log in for the first time simultaneously, will the NFS be able handle the simultaneous appends? if not some sort of central service to handle this could be setup...
    # or I'll just add a little random sleepytime :)
    sleep `awk 'BEGIN{print 5*rand()}'`   # sleep for a random amount between 1 and 5 seconds

    ## if they are an admin, make that their primary group
    if [[ "$ADMIN_USER" == "True" ]]; then
      echo "$NB_USER:x:$NB_UID:$ADMIN_GID:,,,:/home/$NB_USER:/bin/bash" >> $ADMIN_HOME_DIR/automanaged/etc_passwd_additions
    else
      echo "$NB_USER:x:$NB_UID:$USER_GID:,,,:/home/$NB_USER:/bin/bash" >> $ADMIN_HOME_DIR/automanaged/etc_passwd_additions
    fi
  fi
  
  # set umask (defaulting to rw-rw-r-- for files and  rwxrwxr-x for dirs, so that new files are by 
  # default read/write by 
  # NB_USER:(primary group); thus the group and user are set appropriately, but they are writable by anyone
  # in the users group - including admin users. Trick is, only the owner and anyone in $ADMIN_GROUPNAME
  # can access inside home dir itself, because that is owned by NB_USER:$ADMIN_GROUPNAME rwxrwx---)
  echo "Defaults umask=0002" >> /etc/sudoers
  # allow sudo to use this more permissive umasks than the default of union (for use by user jupyter process which is run with sudo -u $NB_USER)
  echo "Defaults umask_override" >> /etc/sudoers

  if [[ ! -f $ADMIN_HOME_DIR/autosourced_by_rprofiles.R ]] ; then
    cp -L /usr/local/bin/various/autosourced_by_rprofiles.R $ADMIN_HOME_DIR/autosourced_by_rprofiles.R
    chown $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/autosourced_by_rprofiles.R
    chmod 664 $ADMIN_HOME_DIR/autosourced_by_rprofiles.R
  fi

  # setup Rstudio Renviron to learn about the R site libraries 
  # note that we have to build the autosourced_by_rprofiles.R here, because Rstudio doesn't get any of the fricken environment variables that jupyter does (and I decided long ago to make $ADMIN_HOME_DIR a var...)
  if [[ ! -d $ADMIN_HOME_DIR/R_libs ]] ; then
    mkdir -p $ADMIN_HOME_DIR/R_libs
    echo "This is the hub-library for R packages, admins can hub.install.packages() directly to here, users cannot, install.packages() works as normal and installs to each users' home directory." > $ADMIN_HOME_DIR/R_libs/README.txt
    chown -R $ADMIN_USERNAME:$ADMIN_GROUPNAME $ADMIN_HOME_DIR/R_libs
    chmod -R 775 $ADMIN_HOME_DIR/R_libs
    chmod 664 $ADMIN_HOME_DIR/R_libs/README.txt

  fi

  # the /etc/profile trick below seems to work, EXCEPT for some vars which RStudio won't read :(
  # probably don't need the greps here
  if [[ -e /opt/conda/lib/R/etc/Renviron ]]; then
    grep "R_LIBS_SITE=$ADMIN_HOME_DIR/R_libs" /opt/conda/lib/R/etc/Renviron || echo "R_LIBS_SITE=$ADMIN_HOME_DIR/R_libs" >> /opt/conda/lib/R/etc/Renviron
    grep "ADMIN_HOME_DIR=$ADMIN_HOME_DIR" /opt/conda/lib/R/etc/Renviron || echo "ADMIN_HOME_DIR=$ADMIN_HOME_DIR" >> /opt/conda/lib/R/etc/Renviron
    grep "DATA_HOME_DIR=$DATA_HOME_DIR" /opt/conda/lib/R/etc/Renviron || echo "DATA_HOME_DIR=$DATA_HOME_DIR" >> /opt/conda/lib/R/etc/Renviron
  fi
}


check_nb_user() {
  ## setup permissions properly for 'classroom' access (admins read/write everywhere, users only in their home), and copy results to the /home mount
  ## Do so *only* if they don't already exist in /home, so this happens only at first login (otherwise every login would result in cleaned out home dirs)
  
  if [[ ! -d /home/$NB_USER ]]; then
    # these permissions and ownership set things up nicely for class usage - instructors mostly all powerful (file permission-wise), students normally-powerful
    chown $NB_UID:$ADMIN_GROUPNAME /tmp/$NB_USER 
    # make sure we have group read on everything, some aren't in the .npm cache dir in the inherited docker image
    chmod -R 770 /tmp/$NB_USER                      
    
    # make a link to $DATA_HOME_DIR
    ln -s $DATA_HOME_DIR /tmp/$NB_USER/$(basename $DATA_HOME_DIR)
    # make sure they have a startup folder for pyhton notebooks
    mkdir -p /tmp/$NB_USER/.ipython/profile_default/startup

    # re-own inner contents
    # chown dotfiles (note, this trick will fail on single-letter dotfiles e.g. '.a')
    chown -R $NB_UID:$USER_GROUPNAME /tmp/$NB_USER/.??* 
    # chown others
    chown -R $NB_UID:$USER_GROUPNAME /tmp/$NB_USER/* 
  
    # TODO: this was outside and referencing /home/$NB_USER, but I was occasionally getting errors e.g.  /home/juser/.ipython/profile_default/startup/001_autoexec.py: No such file or directory
    # maybe an nfs thing? Anyway, putting it here means users can remove it and they won't come back, which might be undesirable
    # make sure they source the autosourced_by_rprofiles, even if they try to remove it ;)
    grep -qxF "source(\"$ADMIN_HOME_DIR/autosourced_by_rprofiles.R\")" /tmp/$NB_USER/.Rprofile || echo "source(\"$ADMIN_HOME_DIR/autosourced_by_rprofiles.R\")" >> /tmp/$NB_USER/.Rprofile
    # make sure they exec the autoexec_by_python_notebooks, even if they try to remove it ;)
    echo "exec(open(\"$ADMIN_HOME_DIR/autoexec_by_python_notebooks.py\").read())" > /tmp/$NB_USER/.ipython/profile_default/startup/001_autoexec.py 
    chown $ADMIN_USERNAME:$ADMIN_GROUPNAME /tmp/$NB_USER/.ipython/profile_default/startup/001_autoexec.py
    chmod 664 /tmp/$NB_USER/.ipython/profile_default/startup/001_autoexec.py

    # copy em over to the /home mount, -a for archive (like cp -r and preserve ownership and other metadata)
    cp -a /tmp/$NB_USER /home
  fi
  
  # if the user is labeled an admin, ensure they are in the admins group, otherwise ensure they aren't
  if [[ "$ADMIN_USER" == "True" ]]; then
    grep -E "^$NB_USER\$" $ADMIN_HOME_DIR/automanaged/etc_group_admins || echo $NB_USER >> $ADMIN_HOME_DIR/automanaged/etc_group_admins
  else
    sed -r -i "/^$NB_USER$/d" $ADMIN_HOME_DIR/automanaged/etc_group_admins
  fi
  
  # ensure they are in the users group no matter what
  grep -E "^$NB_USER\$" $ADMIN_HOME_DIR/automanaged/etc_group_users || echo $NB_USER >> $ADMIN_HOME_DIR/automanaged/etc_group_users
  
  # we're done with the staging in /tmp, remove it
  rm -rf /tmp/$NB_USER
}


update_etc_files() {
  # add entries from the persisted etc_passwd_additions to the container /etc/passwd
  cat $ADMIN_HOME_DIR/automanaged/etc_passwd_additions >> /etc/passwd
  
  # group entries are persisted in $ADMIN_HOME_DIR/automanaged/{etc_group_admins,etc_group_users} as single-col lists
  # we need to first remove the entries from /etc/group if they happen to be there already
  sed -i -r "/^$USER_GROUPNAME:/d" /etc/group
  sed -i -r "/^$ADMIN_GROUPNAME:/d" /etc/group
  
  # make sure they exist before we try to use them
  ls $ADMIN_HOME_DIR/automanaged/etc_group_users || touch $ADMIN_HOME_DIR/automanaged/etc_group_users
  ls $ADMIN_HOME_DIR/automanaged/etc_group_admins || touch $ADMIN_HOME_DIR/automanaged/etc_group_admins
  
  USERLIST=`cat $ADMIN_HOME_DIR/automanaged/etc_group_users | tr '\n' ',' | sed -r 's/(^,+)|(,+$)//g' | sed -r 's/,+/,/g'`
  ADMINLIST=`cat $ADMIN_HOME_DIR/automanaged/etc_group_admins | tr '\n' ',' | sed -r 's/(^,+)|(,+$)//g' | sed -r 's/,+/,/g'`
  echo "$USER_GROUPNAME:x:$USER_GID:$USERLIST" >> /etc/group
  echo "$ADMIN_GROUPNAME:x:$ADMIN_GID:$ADMINLIST,$ADMIN_USERNAME" >> /etc/group
}


main_setup() {
  cd /tmp

  add_admin_group
  stage_home_copies
  do_mount
  set_uid
  check_admin_config
  check_nb_user
  update_etc_files

  # go the new dir rather than leaving CWD to be the no-longer existing original
  cd /home/$NB_USER


  # Add $CONDA_DIR/bin to sudo secure_path
  # (sets the PATH of the sudo to whatever is listed, this sed adds to whatever is there already)
  # there must be a reason to do it this way...
  sed -r "s#Defaults\s+secure_path=\"([^\"]+)\"#Defaults secure_path=\"\1:$CONDA_DIR/bin\"#" /etc/sudoers | grep secure_path > /etc/sudoers.d/path
  
  #############################################
  #### For RStudio
  #############################################
  # note that this is specific to the image RStudio install
  PATH="${PATH}:/usr/lib/rstudio-server/bin"
  LD_LIBRARY_PATH="/usr/lib/R/lib:/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server:/opt/conda/lib/R/lib"
}

main_setup
# Exec the specified command or fall back on bash
if [ $# -eq 0 ]; then
  cmd=( "bash" )
else
  cmd=( "$*" )
fi

# rstudio doesn't get everything, except for what is defined in etc profile (and that doesn't include ADMIN_HOME_DIR unless we define it there)
#echo "export DATA_HOME_DIR=$DATA_HOME_DIR" >> /etc/profile
#echo "export ADMIN_HOME_DIR=$ADMIN_HOME_DIR" >> /etc/profile
#echo "source $ADMIN_HOME_DIR/hubrc" >> /etc/profile
#
#echo "export DATA_HOME_DIR=$DATA_HOME_DIR" >> /etc/rstudio/rsession-profile
#echo "export ADMIN_HOME_DIR=$ADMIN_HOME_DIR" >> /etc/rstudio/rsession-profile
#echo "source $ADMIN_HOME_DIR/hubrc" >> /etc/rstudio/rsession-profile

ln -s $ADMIN_HOME_DIR/hubrc /etc/profile.d/hubrc.sh

# using bash -c causes the stuff in /etc/profile to be picked up
#exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-} bash -c "$cmd"  
exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-} bash -c "$cmd"  
