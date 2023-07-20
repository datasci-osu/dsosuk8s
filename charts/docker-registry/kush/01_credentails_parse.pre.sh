
ADMIN_USERNAME=$(index "basicAuth.username" "$ADMIN_USERNAME")
ADMIN_PASSWORD=$(index "basicAuth.password" "$ADMIN_PASSWORD")

if [ "$ADMIN_USERNAME" == "" ] || [ "$ADMIN_PASSWORD" == "" ]; then
  echo "${red}Error: you must define both basicAuth.username and basicAuth.password in --values.${white}" 1>&2
  exit 1
fi


