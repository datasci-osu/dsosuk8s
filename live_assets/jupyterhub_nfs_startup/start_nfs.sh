#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e
      

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
                if [[ -x "$f" ]] && [[ ! -d "$f" ]]; then
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
# (sets the PATH of the sudo to whatever is listed, this sed adds to whatever is there already)
# there must be a reason to do it this way...
sed -r "s#Defaults\s+secure_path=\"([^\"]+)\"#Defaults secure_path=\"\1:$CONDA_DIR/bin\"#" /etc/sudoers | grep secure_path > /etc/sudoers.d/path

#############################################
#### For RStudio
#############################################
# TODO: I'm not sure I like all this tie-in between the image and the chart (and by extension, this). There's gotta be a better way.
PATH="${PATH}:/usr/lib/rstudio-server/bin"
LD_LIBRARY_PATH="/usr/lib/R/lib:/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server:/opt/conda/lib/R/lib"

echo "Executing the command: ${cmd[@]}"
exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-} "${cmd[@]}"





