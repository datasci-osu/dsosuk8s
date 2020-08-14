
echo "${green}Finished! Hub launch URL:${blue} https://$(index clusterHostname "whoops")/${RELEASE_NAME}/hub/lti/launch${white}" 1>&2
echo "${green}Consumer Key: ${blue}$LTI_CLIENT_KEY${white}" 1>&2
echo "${green}Shared Secret: ${blue}$LTI_CLIENT_SECRET${white}" 1>&2
