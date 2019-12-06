#!/bin/bash
#
#
# Author: $Author$
# Revision: $Revision$
# Date: $Date$
#

# source the configuration file

# global values - start
# global variables - end


## declare an array variable
declare -a PRIMARYARRAY=("skybox_watchdog.sh" "backupTicket.sh" "replicate_fw_config.sh" "replicate_ticket_attachments.sh")
declare -a SECONDARYARRAY=("skybox_watchdog.sh" "conf_files_sync.sh")
## end of declaration

source `dirname $0`/skybox_ha.conf

# remove only Skybox crontab lines
#crontab -u mobman -l | grep -v 'perl /home/mobman/test.pl'  | crontab -u mobman -

if [ -e "$SKYUSERHOME/incron.primary" ]; then
    for VAL in "${PRIMARYARRAY[@]}"; do
       crontab -l | grep -v $VAL | crontab -
    done
else
    for VAL in "${SECONDARYARRAY[@]}"; do
      crontab -l | grep -v $VAL | crontab -
    done
fi

if [ -e "$SKYUSERHOME/incron.primary" ]; then
    PRIMARYTESTRESULTS=`crontab -l | grep -q 'skybox_watchdog.sh|backupTicket.sh|replicate_fw_config.sh|replicate_ticket_attachments.sh' | wc -l`
    if [ "$PRIMARYTESTRESULTS" -eq '0' ]; then
        echo `date +"%Y/%m/%d %H:%M:%S - Crontab cleared successfully"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y/%m/%d %H:%M:%S - Crontab failed to be cleared - try again"` | tee -a $SKYBOXLOG
    fi
else

    SECONDARYTESTRESULTS=`crontab -l | grep -q 'skybox_watchdog.sh|conf_files_sync.sh' | wc -l`
    if [ "$SECONDARYTESTRESULTS" -eq '0' ]; then
        echo `date +"%Y/%m/%d %H:%M:%S - Crontab cleared successfully"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y/%m/%d %H:%M:%S - Crontab failed to be cleared - try again"` | tee -a $SKYBOXLOG
    fi
fi


# delete all iptables
sudo iptables -t nat -F
echo "Removing current IPtables configuration" | tee -a $SKYBOXLOG

# create blank incron.primary and secondary files
if [ -f "$SKYUSERHOME/incron.primary" ]
then
    echo '' > $SKYUSERHOME/incron.primary
    echo `date +"%Y/%m/%d %H:%M:%S - Clearing incron.primary"` | tee -a $SKYBOXLOG
    incrontab $SKYUSERHOME/incron.primary
    if [ $? == 0 ]
    then
	    echo `date +"%Y/%m/%d %H:%M:%S - Incrontab on primary cleared successfully"` | tee -a $SKYBOXLOG
    else
   	    echo `date +"%Y/%m/%d %H:%M:%S - Incrontab on primary failed to be cleared"` | tee -a $SKYBOXLOG
    fi
elif [ -f "$SKYUSERHOME/incron.secondary" ]
then
    echo '' > $SKYUSERHOME/incron.secondary
    incrontab $SKYUSERHOME/incron.secondary
    if [ $? == 0 ]
    then
    	echo `date +"%Y/%m/%d %H:%M:%S - Incrontab on secondary cleared successfully"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y/%m/%d %H:%M:%S - Incrontab on secondary failed to be cleared"` | tee -a $SKYBOXLOG
    fi
else
    echo `date +"%Y/%m/%d %H:%M:%S - No incron files were found!"` | tee -a $SKYBOXLOG
fi

if (( $(service iptables status | grep Active | awk '{ print $2 }' | wc -l) > 0 )); then
    echo "IPtables service is running, prepraing to load configuration"
    sudo /sbin/iptables-restore < $SKYUSERHOME/firewall/iptables-secondary
    if [ $? == 0 ]
    then
        echo `date +"%Y/%m/%d %H:%M:%S - Iptables configuration was uploaded..."` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y/%m/%d %H:%M:%S - Iptables configuration failed to load..."` | tee -a $SKYBOXLOG
        state=1
    fi
elif (( $(service firewalld status | grep Active | awk '{ print $2 }' | wc -l) > 0 )); then
    echo "Firewalld detected..."
    # remove direct.xml to open port 25

    if [ -f "/etc/firewalld/direct.xml" ]; then
        sudo rm /etc/firewalld/direct.xml
    fi


	# copy back original public configuration
    sudo cp $SKYUSERHOME/firewall/original_public.xml /etc/firewalld/zones/public.xml
    sudo firewall-cmd --reload
    if [ $? == 0 ]
    then
        echo `date +"%Y/%m/%d %H:%M:%S - Firewalld configuration was uploaded,firewall was successfully reloaded"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y/%m/%d %H:%M:%S - Firewalld configuration was uploaded, but firewall was not reloaded"` | tee -a $SKYBOXLOG
        state=1
    fi
else
    echo `date +"%Y/%m/%d %H:%M:%S - This is not a recognized version"` | tee -a $SKYBOXLOG
fi

# set task scheduler according to server role in skybox_ha.conf_files_sync
case $SERVER_ROLE in
    1)
    cd $SKYBOX_HOME/server/bin/
    if ./settaskschedulingactivation.sh enable >/dev/null; then
        echo `date +"%Y/%m/%d %H:%M:%S - Task Scheduling has been successfully enabled."` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y/%m/%d %H:%M:%S - Task Scheduling was not enabled. An error has occurred."` | tee -a $SKYBOXLOG
    fi

    ;;

    2)
    cd $SKYBOX_HOME/server/bin/
    if ./settaskschedulingactivation.sh disable >/dev/null; then
        echo `date +"%Y/%m/%d %H:%M:%S - Task Scheduling has been successfully disabled."` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y/%m/%d %H:%M:%S - Task Scheduling was not disabled. An error has occurred."` | tee -a $SKYBOXLOG
    fi
    ;;

        *)
                echo `date +"%Y/%m/%d %H:%M:%S - Server options are not set correctly. Configure the skybox_ha.conf with the correct SERVER_ROLE"` | tee -a $SKYBOXLOG
        ;;
esac

# removing incron.primary or incron.secondary
# removing incrontab files and lllltabs
rm -f $SKYUSERHOME/incron.primary
rm -f $SKYUSERHOME/incron.secondary
incrontab -r
