#!/bin/bash
#
#
# Author: $Author$
# Revision: $Revision$
# Date: $Date$
#


# global variables - start

# sourcing configuration file
source `dirname $0`/skybox_ha.conf

#global variables - stop

# functions - start

#funcDisableTaskScheduler(){
#cd $SKYBOX_HOME/server/bin/
												   
#if ./settaskschedulingactivation.sh disable >/dev/null; then
#        echo `date +"%Y-%m-%d %T - Task Scheduling has been disabled"` | tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
#    else
#        echo `date +"%Y-%m-%d %T - ERROR: Task Scheduling has not been set to false. Please rerun the setsecondary script again."` |
 #       tee -a  $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
#fi
#}


# functions - stop

# main code - start

# scp file from other server to /tmp folder; copy over files from temp to skybox conf directory
if `scp skyboxview@$OTHER_SERVER:$SKYBOX_HOME/server/conf/sb_server.properties /tmp/sb_server.properties`; then
    echo `date +"%Y/%m/%d %H:%M:%S - sb_server.properties copied to temp. Preparing to copy the file..."` | tee -a $SKYBOXLOG
	if `sed -i "s/task_scheduling_activation\=true/task_scheduling_activation\=false/g"  /tmp/sb_server.properties`; then
	    echo `date +"%Y/%m/%d %H:%M:%S -  keep_temp flag was successfully changed to false."` | tee -a $SKYBOXLOG
			if `cp /tmp/sb_server.properties $SKYBOX_HOME/server/conf/sb_server.properties`; then
	            echo `date +"%Y/%m/%d %H:%M:%S - sb_server.properties copied to server conf diretory."` | tee -a $SKYBOXLOG
		        rm /tmp/sb_server.properties
            else
	            echo `date +"%Y/%m/%d %H:%M:%S - sb_server.properties was not copied over"` | tee -a $SKYBOXLOG
	        fi
	else
	    `date +"%Y/%m/%d %H:%M:%S - keep_temp was not changed!."` | tee -a $SKYBOXLOG
	fi
	

else
   echo `date +"%Y/%m/%d %H:%M:%S - sb_server.properties was not copied over. Verify scp settings"` | tee -a $SKYBOXLOG
fi

# 
if `scp skyboxview@$OTHER_SERVER:$SKYBOX_HOME/server/conf/sb_common.properties /tmp/sb_common.properties`; then
    echo `date +"%Y/%m/%d %H:%M:%S - sb_common.properties copied. Preparing for next step..."` | tee -a $SKYBOXLOG
		if `cp /tmp/sb_common.properties $SKYBOX_HOME/server/conf/sb_common.properties`; then
	    echo `date +"%Y/%m/%d %H:%M:%S - sb_common.properties copied to server conf diretory."` | tee -a $SKYBOXLOG 
		rm /tmp/sb_common.properties
    else
	    echo `date +"%Y/%m/%d %H:%M:%S - sb_common.properties was not copied over"` | tee -a $SKYBOXLOG
	fi
else
   echo `date +"%Y/%m/%d %H:%M:%S - sb_common.properties was not copied over. Verify scp settings"` | tee -a $SKYBOXLOG
fi

# main code - stop
