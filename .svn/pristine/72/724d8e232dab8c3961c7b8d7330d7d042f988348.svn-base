#!/bin/bash
#
#
# Author: $Author$
# Revision: $Revision$
# Date: $Date$
#

# global variables - start
source `dirname $0`/skybox_ha.conf
prifile="$SKYUSERHOME/incron.primary"

# global variables - stop

# main code - start

if [ -e $prifile ]; then
    echo `date +"%Y-%m-%d %T -  $TEST_SERVER - Skybox Server Ok"` | tee -a "$FWCONFSYNCLOG" 
	echo `date +"%Y-%m-%d %T - rsync of the fw_config to the remote server $OTHER_SERVER"` | tee -a "$FWCONFSYNCLOG"
    /usr/bin/rsync --log-file=$FWCONFSYNCLOG -av --delete-before $SKYBOX_HOME/data/fw_configs/ $OTHER_SERVER:$SKYBOX_HOME/data/fw_configs/ >/dev/null
else
    echo `date +"%Y-%m-%d %T - Remote server config mis-match - check script and skybox_ha.conf"` | tee -a "$FWCONFSYNCLOG"
fi

# main code - stop