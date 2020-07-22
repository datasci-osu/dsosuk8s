if [ "$ADMIN_USER" == "" ]; then
  export ADMIN_USER=admin
fi	
if [ "$ADMIN_PASSWD" == "" ]; then
  export ADMIN_PASSWD=$(openssl rand -hex 3)
fi
export HTPASSWD_CREDS=$(htpasswd -Bbn $ADMIN_USER $ADMIN_PASSWD)
