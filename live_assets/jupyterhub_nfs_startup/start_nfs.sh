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
# (copied from the default start.sh, because the process is run below with sudo -u $NB_USER, it needs access to where jupyter is installed)
sed -r "s#Defaults\s+secure_path=\"([^\"]+)\"#Defaults secure_path=\"\1:$CONDA_DIR/bin\"#" /etc/sudoers | grep secure_path > /etc/sudoers.d/path
# run `env` here to see environment variables set before sudoing, keep the ones that might be relavent for the user
echo 'Defaults env_keep +="HOSTNAME \
	                   JULIA_DEPOT_PATH \
			   JULIA_PKGDIR \
			   CONDA_DIR CONDA_VERSION \
			   JUPYTERHUB_ACTIVITY_URL \
			   JUPYTERHUB_BASE_URL \
			   HUB_PORT \
			   PWD \
			   MINICONDA_MD5 \
			   PROXY_API_SERVICE_HOST \
			   JUPYTERHUB_USER \
			   ADMIN_HOME_DIR \
			   PROXY_API_PORT_8001_TCP_ADDR \
			   PROXY_PUBLIC_PORT \
			   ADMIN_USER \
			   NB_USER \
			   JULIA_VERSION \
			   JUPYTERHUB_SERVICE_PREFIX \
			   JUPYTERHUB_SERVER_NAME \
			   MEM_GUARANTEE \
			   JUPYTER_IMAGE \
			   MEM_LIMIT \
			   JUPYTERHUB_API_URL \
			   JUPYTERHUB_HOST \
			   JPY_API_TOKEN \
			   XDG_CACHE_HOME \
			   JUPYTERHUB_OAUTH_CALLBACK_URL \
			   JUPYTERHUB_API_TOKEN \
			   MINICONDA_VERSION \
			   JUPYTER_IMAGE_SPEC
                           "' >> /etc/sudoers

cat /etc/sudoers
echo "Executing the command: ${cmd[@]}"
# exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} "${cmd[@]}"
exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} "${cmd[@]}"





