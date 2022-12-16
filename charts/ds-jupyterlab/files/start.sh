#!/bin/bash

## TODO: although this script is broken into functions, it may as well not be - all these variables are global and need to be set in 
## a specific order (spaghetti!), the functions are just use for thematic grouping

set -e


# source some utilities
source /usr/local/bin/data/common.src


update_root_files() {
  ln -s $ADMIN_HOME_DIR/hubrc /etc/profile.d/hubrc.sh
  HOSTNM=$(echo $JUPYTERHUB_BASE_URL | tr -d '/')
  hostname $HOSTNM

  # can access inside home dir itself, because that is owned by NB_USER:$ADMIN_GROUPNAME rwxrwx---)
  echo "Defaults umask=0002" >> /etc/sudoers
  # allow sudo to use this more permissive umasks than the default of union (for use by user jupyter process which is run with sudo -u $NB_USER)
  echo "Defaults umask_override" >> /etc/sudoers

  # the /etc/profile trick below seems to work, EXCEPT for some vars which RStudio won't read :(
  # probably don't need the greps here
  if [[ -e /opt/conda/lib/R/etc/Renviron ]]; then
    grep "R_LIBS_SITE=$ADMIN_HOME_DIR/R_libs" /opt/conda/lib/R/etc/Renviron || echo "R_LIBS_SITE=$ADMIN_HOME_DIR/R_libs" >> /opt/conda/lib/R/etc/Renviron
    grep "ADMIN_HOME_DIR=$ADMIN_HOME_DIR" /opt/conda/lib/R/etc/Renviron || echo "ADMIN_HOME_DIR=$ADMIN_HOME_DIR" >> /opt/conda/lib/R/etc/Renviron
    grep "DATA_HOME_DIR=$DATA_HOME_DIR" /opt/conda/lib/R/etc/Renviron || echo "DATA_HOME_DIR=$DATA_HOME_DIR" >> /opt/conda/lib/R/etc/Renviron
  fi
}


update_user_files() {
  if [ "$FIRST_LOGIN" == "true" ]; then
    cat /usr/local/bin/data/STUDENT_README.md | sed -r "s|@@JUPYTERHUB_BASE_URL@@|$JUPYTERHUB_BASE_URL|" | sed -r "s|@@NB_USER@@|$NB_USER|" >> /home/$NB_USER/README.md 
    chown $NB_UID:$USER_GID /home/$NB_USER/README.md
    chmod 664 /home/$NB_USER/README.md
  fi
  
  grep -sqxF "source(\"$ADMIN_HOME_DIR/autosourced_by_rprofiles.R\")" /home/$NB_USER/.Rprofile || echo "source(\"$ADMIN_HOME_DIR/autosourced_by_rprofiles.R\")" >> /home/$NB_USER/.Rprofile
  grep -sqxF "source(\"$ADMIN_HOME_DIR/autosourced_by_bashrcs\")" /home/$NB_USER/.bashrc || echo "source $ADMIN_HOME_DIR/autosourced_by_bashrcs" >> /home/$NB_USER/.bashrc
  chown $NB_UID:$ADMIN_GID /home/$NB_USER/.Rprofile
  chmod 664 /home/$NB_USER/.Rprofile
  chown $NB_UID:$ADMIN_GID /home/$NB_USER/.bashrc
  chmod 664 /home/$NB_USER/.bashrc
  if [ ! -e /home/$NB_USER/hub_data_share ]; then
    ln -s /home/hub_data_share /home/$NB_USER/.
  fi
}


update_etc_files() {  
  # if the user is labeled an admin, ensure they are in the admins group, otherwise ensure they aren't
  if [[ "$ADMIN_USER" == "True" ]]; then
    # make sure they are in admins group
    grep -E "^$NB_USER\$" $ADMIN_HOME_DIR/automanaged/etc_group_admins || echo $NB_USER >> $ADMIN_HOME_DIR/automanaged/etc_group_admins
    
    # and make sure they have an admin etc_passwd addition
    grep -E "^$NB_USER:x:$NB_UID:$ADMIN_GID" $ADMIN_HOME_DIR/automanaged/etc_passwd_additions || echo "$NB_USER:x:$NB_UID:$ADMIN_GID:,,,:/home/$NB_USER:/bin/bash" >> $ADMIN_HOME_DIR/automanaged/etc_passwd_additions
    # and that they *don't* have a non-admin etc_passwd addition
    sed -r -i "/^$NB_USER:x:$NB_UID:$USER_GID/d" $ADMIN_HOME_DIR/automanaged/etc_passwd_additions || true
    ## and remove group permissions so admins can get some privacy, sheesh - actually, let's not, but we could someday
    # chmod -R og-rwx /home/$NB_USER
  else
    # remove their entry from admins group if they are there
    sed -r -i "/^$NB_USER$/d" $ADMIN_HOME_DIR/automanaged/etc_group_admins

    # and make sure they have a user etc_passwd addition
    grep -E "^$NB_USER:x:$NB_UID:$USER_GID" $ADMIN_HOME_DIR/automanaged/etc_passwd_additions || echo "$NB_USER:x:$NB_UID:$USER_GID:,,,:/home/$NB_USER:/bin/bash" >> $ADMIN_HOME_DIR/automanaged/etc_passwd_additions
    # and that they *don't* have an admin etc_passwd addition
    sed -r -i "/^$NB_USER:x:$NB_UID:$ADMIN_GID/d" $ADMIN_HOME_DIR/automanaged/etc_passwd_additions || true
  fi
  
  # make sure they're in the users group no matter what
  grep -E "^$NB_USER\$" $ADMIN_HOME_DIR/automanaged/etc_group_users || echo $NB_USER >> $ADMIN_HOME_DIR/automanaged/etc_group_users
  
  # add entries from the persisted etc_passwd_additions to the container /etc/passwd
  cat $ADMIN_HOME_DIR/automanaged/etc_passwd_additions >> /etc/passwd
  
  # group entries are persisted in $ADMIN_HOME_DIR/automanaged/{etc_group_admins,etc_group_users} as single-col lists
  # we need to first remove the entries from /etc/group if they happen to be there already
  sed -i -r "/^$USER_GROUPNAME:/d" /etc/group
  sed -i -r "/^$ADMIN_GROUPNAME:/d" /etc/group
   
  USERLIST=`cat $ADMIN_HOME_DIR/automanaged/etc_group_users | tr '\n' ',' | sed -r 's/(^,+)|(,+$)//g' | sed -r 's/,+/,/g'`
  ADMINLIST=`cat $ADMIN_HOME_DIR/automanaged/etc_group_admins | tr '\n' ',' | sed -r 's/(^,+)|(,+$)//g' | sed -r 's/,+/,/g'`
  echo "$USER_GROUPNAME:x:$USER_GID:$USERLIST" >> /etc/group
  echo "$ADMIN_GROUPNAME:x:$ADMIN_GID:$ADMINLIST,$ADMIN_USERNAME" >> /etc/group
}


main_setup() {
  cd /usr/local/bin

  # we're writing to an NFS filesystem, if lots of people login at the same time there could be a lot of I/O to specific files
  # do a quick random sleepytime to try and spread them out in that case (not sure if this is really needed or really helps honestly)
  sleep `awk 'BEGIN{print 5*rand()}'`   # sleep for a random amount between 1 and 5 seconds

  set_common_vars
  create_uids_gids
  stage_home_temp_copy $NB_USER
  
  NB_UID=$(get_uid $NB_USER)

  do_mount $NFS_SVC_HOME /home

  if [ -e /home/$NB_USER ]; then
    export FIRST_LOGIN=false
  else
    export FIRST_LOGIN=true
  fi

  export PYTHONVERSION=`python -c 'import sys; v = sys.version_info; print("python" + str(v[0]) + "." + str(v[1]))'`
  create-dir-structure /usr/local/bin/data/structure.txt
  
  # for hub-admin-adjustable jupyterlab (extensions, kernels, etc) we need the jupyterlab data dir to be in the mount
  # and copy the existing data dir contents there
  # using imports.css as a signifier
  if [ ! -e $ADMIN_HOME_DIR/python_libs/jupyterlab/imports.css ]; then
    rm -rf /opt/conda/share/jupyter/lab/staging
    cp -r /opt/conda/share/jupyter/lab/* $ADMIN_HOME_DIR/python_libs/jupyterlab/
    chown -R $ADMIN_UID:$ADMIN_GID $ADMIN_HOME_DIR/python_libs/jupyterlab/
    chmod -R o+r $ADMIN_HOME_DIR/python_libs/jupyterlab/
    chmod -R ug+rwx $ADMIN_HOME_DIR/python_libs/jupyterlab/
  fi

  update_root_files
  update_user_files
  update_etc_files


  # go the new dir rather than leaving CWD to be the no-longer existing original
  cd /home/$NB_USER
  # remove /tmp/username (esquisse library and/or shiny server are trying to write there and failing because it already exists)
  # rm -rf /tmp/$NB_USER

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
  JUPYTERLAB_DIR=$ADMIN_HOME_DIR/python_libs/jupyterlab
}

main_setup
# Exec the specified command or fall back on bash
if [ $# -eq 0 ]; then
  cmd=( "bash" )
else
  cmd=( "$*" )
fi

export PATH=$ADMIN_HOME_DIR/bin:$PATH
export PYTHONPATH=$ADMIN_HOME_DIR/python_libs/lib/$PYTHONVERSION/site-packages
export PATH=$ADMIN_HOME_DIR/python_libs/bin:$PATH
export R_LIBS_SITE=$ADMIN_HOME_DIR/R_libs


# using bash -c causes the stuff in /etc/profile to be picked up
#exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-} bash -c "$cmd"  
exec sudo -E -H -u $NB_USER \
  PATH=$PATH \
  FIRST_LOGIN=$FIRST_LOGIN \
  R_LIBS_SITE=${R_LIBS_SITE:-} \
  XDG_CACHE_HOME=/home/$NB_USER/.cache \
  JUPYTERLAB_DIR=${JUPYTERLAB_DIR:-} \
  PYTHONPATH=${PYTHONPATH:-} \
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-} \
  ADMIN_HOME_DIR=${ADMIN_HOME_DIR} \
  ADMIN_USER=${ADMIN_USER} \
  bash -c "$cmd"
