#!/bin/bash
#
#
# Author: $Author$
# Revision: $Revision$
# Date: $Date$
#

# source the configuration file
source `dirname $0`/skybox_ha.conf

# global variables - start

prifile="$SKYUSERHOME/incron.primary"
MYSQLDUMP=`find /opt/skyboxview/thirdparty -path "*bin/mysqldump"`

# global variables - stop

# script start

# Check if this server is either Primary or secondary (if not exist)
 if [ -e $prifile ]; then
     echo "Production Primary Skybox Server Ok"
 
 #I'm primary export ticket
NOW=$(date +"%Y%d%m%H%M%S")
$MYSQLDUMP --user root --password=manager -S /opt/skyboxview/data/db/mysql/mysql.sock skyboxview_live sbv_tickets sbv_ticket_events sbv_ticket_fields sbv_attachments sbv_phases > /opt/skyboxview/data/xml_models/ticket_backup.sql.$NOW
    echo $NOW
    echo `date +"%Y/%m/%d %H-%M-%S - Backup tickets finished successfully"` | tee -a $SKYBOXLOG
else
    echo "Not Primary Skybox Server"
    exit 255
fi


# script stop