#!/bin/bash
#
#
# Author: $Author$
# Revision: $Revision$
# Date: $Date$
#

# global variables - start

source `dirname $0`/skybox_ha.conf

FILENAME=${1##*/}

# global variables - stop
#add logic for errors - file not match or blank

# main code - start
cd $SKYBOX_HOME/server/bin

# check if last 5 characters equals sqlx, if so, use sqlxrestore
if [[ ${1: -5} == ".sqlx" ]] 
then
        echo sqlxrestore.sh $1 -model
        #echo "TIME=$(date)" > $MODELSTATUS
        date +"%Y-%m-%d %T - FILENAME=$1" | tee -a $MODELSTATUS

        if ./sqlxrestore.sh -user_tables -model_tables $1 2>&1 >> $SKYBOXLOG; then
            date +"%Y-%m-%d %T - Restoration of sql file: $FILENAME - SUCCESS" | tee -a $MODELSTATUS
		    date +"%Y-%m-%d %T - Restoration of sql file: $FILENAME - SUCCESS" | tee -a $SKYBOXLOG
        else
            date +"%Y-%m-%d %T - Restoration of sql file: $FILENAME - FAILED" | tee -a $MODELSTATUS
		    date +"%Y-%m-%d %T - Restoration of sql file: $FILENAME - FAILED" | tee -a $SKYBOXLOG
        fi

# check if the file name is ticket_backup, if so, load via mysql.sh
elif [[ ${1%*.*} == "/opt/skyboxview/data/xml_models/ticket_backup.sql" ]]; then
            echo "mysql.sh $1"
            #echo "TIME=$(date)" > $LOADSTATUS
             date +"%Y-%m-%d %T - FILENAME=$1" >> $LOADSTATUS
             ./mysql.sh --database=skyboxview_live --password=manager < $1 2>&1 | tee -a $SKYBOXLOG

            if [ $? == 0 ]; then
                ./invalidate.sh
                 date +"%Y-%m-%d %T -  Restoration of backup_sql file: $FILENAME - SUCCESS" | tee -a $LOADSTATUS
			     date +"%Y-%m-%d %T -  Restoration of backup_sql file: $FILENAME - SUCCESS" | tee -a $SKYBOXLOG
				 
				 if rm -f $1; then
				     date +"%Y-%m-%d %T -  Removing of ticket backup file: $FILENAME - SUCCESS" | tee -a $LOADSTATUS
			         date +"%Y-%m-%d %T -  Restoration of backup_sql file: $FILENAME - SUCCESS" | tee -a $SKYBOXLOG
				else
					 date +"%Y-%m-%d %T -  Restoration of backup_sql file: $FILENAME - FAILURE" | tee -a $LOADSTATUS
			         date +"%Y-%m-%d %T -  Restoration of backup_sql file: $FILENAME - FAILURE" | tee -a $SKYBOXLOG
				fi
				
            else
                 date +"%Y-%m-%d %T - Restoration of backup_sql file: $FILENAME - FAILED" |  tee -a $LOADSTATUS
			     date +"%Y-%m-%d %T - Restoration of backup_sql file: $FILENAME - FAILED" | tee -a $SKYBOXLOG
            fi
# check if the last 5 characters of filename is xmlx, then load model using xmlx load.sh script
else
        if [[ ${1: -5} == ".xmlx" ]] ; then
		     
             echo "load.sh $1 -model"
             date +"%Y-%m-%d %T - FILENAME=$1" | tee -a $MODELSTATUS

                if ./load.sh $1 -model -coreusers -core | tee -a $SKYBOXLOG ; then
				    date +"%Y-%m-%d %T - Model Upload Status - $FILENAME - SUCCESS" | tee -a $MODELSTATUS
				    date +"%Y-%m-%d %T - Model Upload Status - $FILENAME - SUCCESS" | tee -a $SKYBOXLOG
                else
                    date +"%Y-%m-%d %T - Model Upload Status - $FILENAME - FAILED" | tee -a $MODELSTATUS
				    date +"%Y-%m-%d %T - Model Upload Status - $FILENAME - FAILED" | tee -a $SKYBOXLOG
                fi
        fi
fi

# main code - stop