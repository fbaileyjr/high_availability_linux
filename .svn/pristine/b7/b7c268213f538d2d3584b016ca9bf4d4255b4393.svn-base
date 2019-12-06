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
    echo `date +"%Y-%m-%d %T -  $TEST_SERVER - Skybox Server Ok"` | tee -a "$LOADSTATUS"
	echo `date +"%Y-%m-%d %T -  rsyncing the Ticket Attachments with the counterpart server - $OTHER_SERVER"` | tee -a "$LOADSTATUS"
	#fw_config_sync.log
    /usr/bin/rsync --log-file=$LOADSTATUS -av --delete-before $SKYBOX_HOME/data/ticket_attachments/ $OTHER_SERVER:$SKYBOX_HOME/data/ticket_attachments/ >/dev/null
else
	echo `date +"%Y-%m-%d %T - Remote server config mis-match - check script and skybox_ha.conf"` | tee -a "$LOADSTATUS"
fi

# main code - stop

