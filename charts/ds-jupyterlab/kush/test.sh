#!/usr/local/bin/bash

unset BASHMATIC_HOME
source bashmatic/init.sh
color.disable
color.enable

bashmatic.functions

sleep 1
red 1
sleep 1
red 2
sleep 1
red 3

exit 0
if run.ui.ask Continue?; then
  ls
fi

success hell yeah
h1.blue hi
h2 there
h3 shawn
