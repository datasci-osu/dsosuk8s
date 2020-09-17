
echo "${green}All set. Access your grafana dashboards at ${cyan}https://$(index clusterHostname "UHOH PROBLEM")/$RELEASE_NAME ${white}" 1>&2
echo "${green}Initial admin login is ${cyan}admin/$(index adminPassword "NONE SET?")" 1>&2

if [ "$DRY_RUN" == "True" ]; then
  echo "${yellow}But not really, DRY_RUN is set (template or --dry-run used) ${white}"
fi
