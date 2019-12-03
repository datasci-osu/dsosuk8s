#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

echo "this script is a modification of the default jupyter-stack base-notebook start.sh; \
  we make the assumption the container is started as root; this calls out to scripts \
  in /usr/local/etc/start-notebook.d/ to do various setups before spawning the notebook \
  server as the user."

echo "This is the default start.sh, *except* for swapping blocks A and B below" 
echo "(original order seems like a bug, unless /home/NB_USER is already mounted in or NB_USER is set to the default of jovyan)"

# Exec the specified command or fall back on bash
if [ $# -eq 0 ]; then
    cmd=( "bash" )
else
    cmd=( "$@" )
fi

run-hooks () {
    # Source scripts or run executable files in a directory
    if [[ ! -d "$1" ]] ; then
        return
    fi
    echo "$0: running hooks in $1"
    for f in "$1/"*; do
        case "$f" in
            *.sh)
                echo "$0: running $f"
                source "$f"
                ;;
            *)
                if [[ -x "$f" ]] ; then
                    echo "$0: running $f"
                    "$f"
                else
                    echo "$0: ignoring $f"
                fi
                ;;
        esac
    done
    echo "$0: done running hooks in $1"
}

run-hooks /usr/local/bin/start-notebook.d

# Add $CONDA_DIR/bin to sudo secure_path
# (also in the default start.sh, because the process is run below with sudo -u $NB_USER, it needs access to where jupyter is installed)
sed -r "s#Defaults\s+secure_path=\"([^\"]+)\"#Defaults secure_path=\"\1:$CONDA_DIR/bin\"#" /etc/sudoers | grep secure_path > /etc/sudoers.d/path


echo "Executing the command: ${cmd[@]}"
exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} "${cmd[@]}"