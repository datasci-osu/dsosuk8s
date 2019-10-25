#!/usr/bin/env bash

GLAUTHVERSION=v1.1.1
SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`

wget https://github.com/glauth/glauth/releases/download/${GLAUTHVERSION}/glauth64 -O $SCRIPTPATH/../glauth64
