
AUTH_TYPE=$(index authType 'lti')
ADMIN_USERS=$(index adminUsers '')
if [ "$AUTH_TYPE" == "lti" ]; then
  echo "${green}Hub launch URL:${cyan} https://$(index clusterHostname "whoops")/${RELEASE_NAME}/hub/lti/launch${white}" 1>&2
  echo "${green}Consumer Key: ${cyan}$LTI_CLIENT_KEY${white}" 1>&2
  echo "${green}Shared Secret: ${cyan}$LTI_CLIENT_SECRET${white}" 1>&2
else 
  echo "${green}Auth type is ${cyan}$AUTH_TYPE${white}" 1>&2
  echo "${green}Admin users: ${cyan}$ADMIN_USERS${white}" 1>&2
fi

if [ "$DRY_RUN" != "True" ]; then
  echo "${yellow}This is a *dry run* (using helm template or --dry-run), no install performed.${white}" 1>&2
fi
