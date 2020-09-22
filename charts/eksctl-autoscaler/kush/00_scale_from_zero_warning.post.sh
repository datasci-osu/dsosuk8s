echo "${red}WARNING: ${cyan}Because of a glitch w/ AWS, if you currently have any nodegroups at size 0, " 1>&2
echo "you should manually scale them up to size 1 for the autoscaler to recognize them. The " 1>&2
echo "autoscaler will scale them back down to 0 automatically when it notices they are not needed.${white} " 1>&2

if [ "$DRY_RUN" == "True" ]; then
  echo "${yellow}(Not running, dry-run (using template or --dry-run))" 1>&2
fi
