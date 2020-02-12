#!/bin/bash

# note: need to upload stress.R (in kubernetes_dev currently) to /home/hub_local/bin and make exec before running this
# custom hubtraf installed from 
# pip3 install git+https://github.com/oneilsh/hubtraf.git


SESSION_MIN_SECS=30
SESSION_MAX_SECS=120
LOGIN_TIME_SPAN_SECS=120
NUM_USERS=40
TESTNAME=burst

hubtraf --user-session-min-runtime $SESSION_MIN_SECS \
	--user-session-max-runtime $SESSION_MAX_SECS \
	--user-session-max-start-delay $LOGIN_TIME_SPAN_SECS \
	--user-prefix $TESTNAME \
	--code 'import subprocess; subprocess.check_output("/home/hub_local/bin/stress.R", shell = True)' \
	https://devb.datasci.oregonstate.edu/scaletest \
	$NUM_USERS
