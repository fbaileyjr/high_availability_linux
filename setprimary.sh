#!/bin/sh
#
#
# Author: $Author: frank.bailey $
# Revision: $Revision: 28 $
# Date: $Date: 2019-02-21 09:59:54 -0500 (Thu, 21 Feb 2019) $
#

# global variables - start

source `dirname $0`/skybox_ha.conf
TESTFIREWALLD=`ps -ef | grep -v grep | grep firewalld | wc -l`
state=0

# global variables - stop

# functions - start

function sendtestemail(){
        if [ -n $MAIL_SENDER ] || [ -n $MAIL_RECIVER ]; then
        echo `date +"%Y/%m/%d %H:%M:%S - Server role set as primary. Sending test email notification to $MAIL_RECEIVER"` | tee -a $SKYBOXLOG
                cd $SKYBOX_HOME/server/bin/
                ./skyboxmail.sh -from $MAIL_SENDER -to $MAIL_RECEIVER -subject "Test Email - Skybox Primary server -  $(date)" | tee -a $SKYBOXLOG
        else
                echo `date +"%Y/%m/%d %H:%M:%S - No mail parameters supplied"` | tee -a $SKYBOXLOG
        fi
}

# functions - stop


# main code - start
# logic to verify if the user is skyboxview; else exits
if [ `whoami` == 'skyboxview' ]; then
    echo "The user is $(whoami). Proceeding to set as primary..." | tee -a $SKYBOXLOG
else
    echo " The user is $(whoami) . Script must be ran as the skyboxview user. Exiting script..." | tee -a $SKYBOXLOG
    exit 1
fi

# check to see if server is primary
if (ssh -o ConnectTimeout=10 skyboxview@$OTHER_SERVER "ls $SKYUSERHOME/incron.primary" >/dev/null 2>&1)  && [ "$SERVER_ROLE" -eq '1' ];
then 
	echo "Other server is already primary... aborting"
	exit
fi

# removing incrontab files and l tabs
if `rm -f $SKYUSERHOME/incron.*`; then
    echo "Removed incron files..." | tee -a $SKYBOXLOG
else
    echo "There was an issue removing the incron files. Please investigate, if needed..." | tee -a $SKYBOXLOG
    exit 1
fi
incrontab -r

# recreating incrontab.primary
for dir in ${DIRECTORIES[@]}
 do
    	echo $dir/ IN_CLOSE_WRITE /usr/bin/rsync --log-file=$SKYUSERHOME/log/skybox_ha.log -av \$@/$\# $OTHER_SERVER:$dir/ >> incron.primary
 done

echo $SKYBOX_HOME/data/Live/reports/ IN_CLOSE_WRITE /usr/bin/rsync --log-file=$SKYUSERHOME/log/skybox_ha.log -rav \$@/$\# $OTHER_SERVER:$SKYBOX_HOME/data/Live/reports/ >> $SKYUSERHOME/incron.primary
echo $SKYBOX_HOME/data/collector/data_collector/ IN_CLOSE_WRITE /usr/bin/rsync --log-file=$SKYUSERHOME/log/skybox_ha.log -rav \$@/$\# $OTHER_SERVER:$SKYBOX_HOME/data/collector/data_collector >> $SKYUSERHOME/incron.primary


incrontab incron.primary
incrontab -d

# Reset skyboxcrontab and add watchdog script, else remove auto failover if not configured
if [ "$1" == "auto" ]; then
	echo "Resetting skybox crontab and adding watchdog script"
	crontab -l > $SKYUSERHOME/cron
	#sed -i '/skybox_watchdog.sh/d' $SKYUSERHOME/cron
	if ! (grep -Fxq '*/$REST_PING_INTERVAL * * * * $SKYUSERHOME/skybox_watchdog.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
	then
            echo "*/$REST_PING_INTERVAL * * * * $SKYUSERHOME/skybox_watchdog.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
	else
	    date +"%Y-%m-%d %T - Watchdog Cron entry already exist" | tee -a $SKYBOXLOG
	fi
	if !(grep -Fxq '*/60 * * * * $SKYUSERHOME/backupTicket.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
	then
	    echo "*/60 * * * * $SKYUSERHOME/backupTicket.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
	else
	    date +"%Y-%m-%d %T - BackupTicket Cron entry already exist" | tee -a $SKYBOXLOG
	fi
	if !(grep -Fxq '*/60 * * * * $SKYUSERHOME/replicate_fw_config.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
	then
	    echo "*/60 * * * * $SKYUSERHOME/replicate_fw_config.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
        else
	    date +"%Y-%m-%d %T - ReplicateFirewalls Cron entry already exist" | tee -a $SKYBOXLOG
	fi
	if !(grep -Fxq '*/5 * * * * $SKYUSERHOME/replicate_ticket_attachments.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
	then
	    echo "*/5 * * * * $SKYUSERHOME/replicate_ticket_attachments.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
        else
	    echo `date +"%Y-%m-%d %T - ReplicateTicketAttachments Cron entry already exist"` | tee -a $SKYBOXLOG
	fi

	crontab $SKYUSERHOME/cron

else
	echo "Removing skybox_watchdog.sh from crontab, auto failover is not configured"
        crontab -l > $SKYUSERHOME/cron
        sed -i '/skybox_watchdog.sh/d' $SKYUSERHOME/cron
	    sed -i '/conf_files_sync.sh/d' $SKYUSERHOME/cron
        
        if !(grep -Fxq '*/60 * * * * $SKYUSERHOME/backupTicket.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
        then
            echo "*/60 * * * * $SKYUSERHOME/backupTicket.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
        else
            date +"%Y-%m-%d %T - BackupTicket Cron entry already exist" | tee -a $SKYBOXLOG
        fi
        if !(grep -Fxq '*/60 * * * * $SKYUSERHOME/replicate_fw_config.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
        then
            echo "*/60 * * * * $SKYUSERHOME/replicate_fw_config.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
        else
            date +"%Y-%m-%d %T - ReplicateFirewalls Cron entry already exist" | tee -a $SKYBOXLOG
        fi	
    	
	    if !(grep -Fxq '*/5 * * * * $SKYUSERHOME/replicate_ticket_attachments.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
	         then
	              echo "*/5 * * * * $SKYUSERHOME/replicate_ticket_attachments.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
             else
	              echo `date +"%Y-%m-%d %T - ReplicateTicketAttachments Cron entry already exist"` | tee -a $SKYBOXLOG
	    fi
		
        crontab $SKYUSERHOME/cron
	echo "To enable auto failover, rerun this script as the following:"
	echo "$0 auto"
  	state=1
fi

# Set iptables to nat 443 to 8443 with floating IP for primary


if [ $TESTFIREWALLD -gt '0' ] && [ $DISABLE_FIREWALLS == "false" ]; then
    echo "Detected Firewalld service, loading configuration..."
    sudo cp $SKYUSERHOME/firewall/masq_public.xml /etc/firewalld/zones/public.xml
    sudo firewall-cmd --reload
    if [ $? == 0 ]; then
        date +"%Y-%m-%d %T - Firewalld configuration was uploaded, firewall was successfully reloaded"  | tee -a $SKYBOXLOG
    else
        date +"%Y-%m-%d %T - Firewalld configuration was uploaded, but firewall was not reloaded" | tee -a $SKYBOXLOG
        state=1
    fi
elif [ $TESTFIREWALLD -gt '0' ] && [ $DISABLE_FIREWALLS == "true" ]; then
    echo "Detected Firewalld service, loading configuration..."
    sudo cp $SKYUSERHOME/firewall/masq_disable_public.xml /etc/firewalld/zones/public.xml
    sudo firewall-cmd --reload
    
    if [ $? == 0 ]; then
        date +"%Y-%m-%d %T - Firewalld configuration was uploaded, allowing all traffic.  Firewall was successfully reloaded"  | tee -a $SKYBOXLOG
    else
        date +"%Y-%m-%d %T - Firewalld configuration was uploaded, but firewall was not reloaded" | tee -a $SKYBOXLOG
        state=1
    fi
elif [ $TESTFIREWALLD -eq '0' ] && [ $DISABLE_FIREWALLS == "true" ]; then
    echo "Detected IPTables service, loading configuration..."
    sudo /sbin/iptables-restore < $SKYUSERHOME/firewall/iptables-primary-disable
    
    if [ $? == 0 ]; then
 	    date +"%Y-%m-%d %T - Iptables configuration was uploaded..." | tee -a $SKYBOXLOG
    else
  	    date +"%Y-%m-%d %T - Iptables configuration failed to load..." | tee -a $SKYBOXLOG
        state=1
    fi
else
    echo "Detected IPTables service, loading configuration..."
    sudo /sbin/iptables-restore < $SKYUSERHOME/firewall/iptables-primary
    
    if [ $? == 0 ];then
 	date +"%Y-%m-%d %T Iptables configuration was uploaded..." | tee -a $SKYBOXLOG
    else
  	date +"%Y-%m-%d %T Iptables configuration failed to load..." | tee -a $SKYBOXLOG
        state=1
    fi    
fi
#sudo /sbin/iptables-restore < $SKYUSERHOME/iptables-primary



# set email options for notification

if [ -z $MAIL_SENDER ] && [ -z $MAIL_RECEIVER ]; then
        echo `date +"%Y/%m/%d %H:%M:%S No mail parameters supplied"` | tee -a $SKYBOXLOG
elif [ -z $MAIL_SENDER ] && [ -n $MAIL_RECEIVER ]; then
		echo `date +"%Y/%m/%d %H:%M:%S Warning! Mail Receiver address is configured, but not the Mail Sender."` | tee -a $SKYBOXLOG
elif [ -n $MAIL_SENDER ] && [ -z $MAIL_RECEIVER ]; then
		echo `date +"%Y/%m/%d %H:%M:%S Warning! Mail Sender address is configured, but not the Mail Receiver."` | tee -a $SKYBOXLOG
elif [ -n $MAIL_SENDER ] && [ -n $MAIL_RECEIVER ]; then
	    echo `date +"%Y/%m/%d %H:%M:%S - Mail parameters have been configured. Proceeding to next step."` | tee -a $SKYBOXLOG
		sendtestemail
fi



# activate task scheduling in sb_server.properties
if ! crontab -l | grep -Fxq '*/60 * * * * $SKYUSERHOME/conf_files_sync.sh >/dev/null 2>&1'
then
    date +"%Y-%m-%d %T Enabling Task Scheduling..." | tee -a $SKYBOXLOG
    echo "Enabling Task Scheduling..."
    cd /opt/skyboxview/server/bin/
    ./settaskschedulingactivation.sh enable >/dev/null
else
    date +"%Y-%m-%d %T Disabling Task Scheduling as conf_files_sync exists in cron..." | tee -a $SKYBOXLOG
    echo "Disabling Task Scheduling as conf_files_sync exists in cron..."
    cd /opt/skyboxview/server/bin/
    ./settaskschedulingactivation.sh disable >/dev/null
    state=1
fi

# enabling _collectors_auto_update flag in sb_server.properties
cd $SKYBOX_HOME/server/bin/
if grep -rni "enable_collectors_auto_update=false" $SKYBOX_HOME/server/conf/sb_server.properties
    then
        echo `date +"%Y-%m-%d %T, - Enable_collectors_auto_update flag is set to false, changing flag to true"` | tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
        sed -i 's/enable_collectors_auto_update=false/enable_collectors_auto_update=true/g' $SKYBOX_HOME/server/conf/sb_server.properties
        if [ $? == 0 ]
            then
                echo `date +"%Y-%m-%d %T, enable_collectors_auto_update flag has been successfully set to true..."` |
                tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
                state=0
            else
                echo `date +"%Y-%m-%d %T - Enable_collectors_auto_update flag has not been set to true, please rerun script"` |
                tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
                state=1
        fi
    else
        date +"%Y-%m-%d %T, enable_collectors_auto_update flag is set to true, no change needed..." |
        tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
		state=0
fi



# Verification if any checks failed
if [ $state == 0 ]
then
   echo `date +"%Y-%m-%d %T - Host has been successfully set as primary"` | tee -a $SKYBOXLOG
else
   echo `date +"%Y-%m-%d %T - Host failed to be set as primary"`| tee -a $SKYBOXLOG
fi


# main code - stop
