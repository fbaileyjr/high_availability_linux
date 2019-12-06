#!/bin/bash
#
#
# Author: $Author: frank.bailey $
# Revision:$Revision: 28 $
# Date: $Date: 2019-02-21 09:59:54 -0500 (Thu, 21 Feb 2019) $
#
# Additional Logic provided by Filippo Dino
#

# global variables - start
source `dirname $0`/skybox_ha.conf
TESTFIREWALLD=`ps -ef | grep -v grep | grep firewalld | wc -l`
state=0

# global variables - end

# main code - start

# logic to verify if the user is skyboxview; else exits
if [ `whoami` == 'skyboxview' ]; then
    echo "The user is $(whoami). Proceeding to set as secondary..." | tee -a $SKYBOXLOG
else
    echo " The user is $(whoami) . Script must be ran as the skyboxview user. Exiting script..." | tee -a $SKYBOXLOG
    exit 1
fi

# verify if the ticket_attachments folder exists
if [ -d $SKYBOX_HOME/data/ticket_attachments ]; then
    echo "$SKYBOX_HOME/data/ticket_attachments exists"
else
    echo "$SKYBOX_HOME/data/ticket_attachments doesn't exist. Creating ticket_attachments folder..."
	if `mkdir $SKYBOX_HOME/data/ticket_attachments`; then
	    echo `date +"%Y-%m-%d %T - $SKYBOX_HOME/data/ticket_attachments was created successfully"` | tee -a $SKYBOXLOG
	else
	    echo `date +"%Y-%m-%d %T - $SKYBOX_HOME/data/ticket_attachments failed to be created. Please check folder permissions"` | tee -a $SKYBOXLOG
    fi
fi

# removing incrontab files and tabs
if [ -f "$SKYUSERHOME/incron.primary" ]
then
    echo "Removing incron.primary..."
    rm -f $SKYUSERHOME/incron.primary
    if [ $? == 0 ]
    then
        echo `date +"%Y-%m-%d %T - Incron.primary file was removed successfully"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Incron.primary file failed to be removed"` | tee -a $SKYBOXLOG
    fi
elif [ -f "$SKYUSERHOME/incron.secondary" ]
then
    echo "Removing incron.secondary file..."
    rm -f $SKYUSERHOME/incron.secondary
    if [ $? == 0 ]
    then
        echo `date +"%Y-%m-%d %T - Incron.secondary file was removed successfully"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Incron.secondary file failed to be removed"` | tee -a $SKYBOXLOG
    fi
else
    echo `date +"%Y-%m-%d %T - No incron files were found!"` | tee -a $SKYBOXLOG
fi

#removing incrontab
incrontab -r

# adding cron entries for secondary
echo $SKYBOX_HOME/data/xml_models IN_MOVED_TO $SKYUSERHOME/load.sh \$@/\$\# >> $SKYUSERHOME/incron.secondary
echo $SKYBOX_HOME/data/sqlx_models IN_MOVED_TO $SKYUSERHOME/load.sh \$@/\$\# >> $SKYUSERHOME/incron.secondary
incrontab $SKYUSERHOME/incron.secondary
incrontab -d
#sudo /sbin/iptables-restore < $SKYUSERHOME/iptables-secondary
#sudo service iptables restart
if [ "$1" == "auto" ]; then
        echo "Resetting skybox crontab and adding watchdog script"
        crontab -l > $SKYUSERHOME/cron
        sed -i '/skybox_watchdog.sh/d' $SKYUSERHOME/cron
        sed -i '/backupTicket.sh/d' $SKYUSERHOME/cron
        sed -i '/replicate_fw_config.sh/d' $SKYUSERHOME/cron
        if ! (grep -Fxq '*/$REST_PING_INTERVAL * * * * $SKYUSERHOME/skybox_watchdog.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
        then
            echo "*/$REST_PING_INTERVAL * * * * $SKYUSERHOME/skybox_watchdog.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
        else
            date +"%Y-%m-%d %T - Watchdog Cron entry already exist" | tee -a $SKYBOXLOG
        fi
        if !(grep -Fxq '*/60 * * * * $SKYUSERHOME/conf_files_sync.sh >/dev/null 2>&1' $SKYUSERHOME/cron)
        then
            echo "*/60 * * * * $SKYUSERHOME/conf_files_sync.sh >/dev/null 2>&1" >> $SKYUSERHOME/cron
        else
            echo `date +"%Y-%m-%d %T - Conf_files_sync Cron entry already exist"` | tee -a $SKYBOXLOG
        fi
        crontab $SKYUSERHOME/cron
        echo `date +"%Y-%m-%d %T - Setsecondary run with auto"` | tee -a $SKYBOXLOG
else
        echo "Removing skybox_watchdog.sh from crontab, auto failover is not configured"
        crontab -l > $SKYUSERHOME/cron
        sed -i '/skybox_watchdog.sh/d' $SKYUSERHOME/cron
	sed -i '/backupTicket.sh/d' $SKYUSERHOME/cron
	sed -i '/replicate_fw_config.sh/d' $SKYUSERHOME/cron
        crontab $SKYUSERHOME/cron
        echo "To enable auto failover, rerun this script as follows"
        echo "$0 auto"
        echo `date +"%Y/%m/%d %T - Setsecondary run without auto"` | tee -a $SKYBOXLOG
        state=1
fi

# Set firewalls back to original installation state

# set firewalld to block secondary gui id for firewalld with standard ports are blocked
if [ $TESTFIREWALLD -gt '0' ] && [ $DISABLE_FIREWALLS == "false" ] && [ $DISABLE_SECONDARY_GUI == "true" ]; then
    echo "Detected Firewalld, loading configuration..."
    echo "Disable Secondary Gui is set to true..."
    echo "Allow all ports is set to false..."
    
	# add port 25 block on direct interface
	sudo cp $SKYUSERHOME/firewall/direct.xml /etc/firewalld/
	
	# add block secondary gui xml to correct zones/public
    sudo cp $SKYUSERHOME/firewall/block_secondary_gui.xml /etc/firewalld/zones/public.xml
    sudo firewall-cmd --reload
    if [ $? == 0 ]
    then
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, firewall with secondary gui disabled was successfully reloaded"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, but firewall was not reloaded"` | tee -a $SKYBOXLOG
        state=1
    fi

# set firewalld to block secondary gui id for firewalld, but allow ALL other ports
elif [ $TESTFIREWALLD -gt '0' ] && [ $DISABLE_FIREWALLS == "true" ] && [ $DISABLE_SECONDARY_GUI == "true" ]; then
    echo "Detected Firewalld, loading configuration..."
    echo "Disable Secondary Gui is set to true..."
    echo "Allow all ports set to true" 
	
	# add block secondary gui xml to correct zones/public
    sudo cp $SKYUSERHOME/firewall/block_secondary_gui_allow_all.xml /etc/firewalld/zones/public.xml
    sudo firewall-cmd --reload
    if [ $? == 0 ]
    then
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, firewall with secondary gui and disable firewalls enabled was successfully reloaded"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, but firewall was not reloaded"` | tee -a $SKYBOXLOG
        state=1
    fi

# set firewalld to original configuration
elif [ $TESTFIREWALLD -gt '0' ] && [ $DISABLE_FIREWALLS == "false" ] && [ $DISABLE_SECONDARY_GUI == "false" ]; then
    echo "Detected Firewalld, loading configuration..."
    echo "Disable Secondary Gui is set to true..."
    echo "Allow all ports set to false..."
    
	# add port 25 block on direct interface
	sudo cp $SKYUSERHOME/firewall/direct.xml /etc/firewalld/
	
	
	# add original configuration for secondary
    sudo cp $SKYUSERHOME/firewall/original_public.xml /etc/firewalld/zones/public.xml
    sudo firewall-cmd --reload
    if [ $? == 0 ]
    then
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, firewall with secondary gui disabled was successfully reloaded"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, but firewall was not reloaded"` | tee -a $SKYBOXLOG
        state=1
    fi

# set firewalld to allow traffic due to disable_firewalls flag enabled to true
elif [ $TESTFIREWALLD -gt '0' ] && [ $DISABLE_FIREWALLS == "true" ] && [ $DISABLE_SECONDARY_GUI == "false" ]; then
    echo "Detected Firewalld, loading configuration..."
    echo "Disable Secondary Gui is set to true..."
	# add port 25 block on direct interface
	sudo cp $SKYUSERHOME/firewall/direct.xml /etc/firewalld/
	
	
	# add original configuration for secondary
    sudo cp $SKYUSERHOME/firewall/original_public_disable.xml /etc/firewalld/zones/public.xml
    sudo firewall-cmd --reload
    if [ $? == 0 ]
    then
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, firewall with secondary gui disabled, but disable all firewalls was successfully reloaded"` | tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Firewalld configuration was uploaded, but firewall was not reloaded"` | tee -a $SKYBOXLOG
        state=1
    fi


# if no gui is set to true, but disable_firewalls is set to false, disable port 8443 and allow normal traffic for IPTABLES
elif [ $TESTFIREWALLD -eq '0' ] && [ $DISABLE_FIREWALLS == "false" ] && [ $DISABLE_SECONDARY_GUI == "true" ]; then
    echo "Detected IPTables, loading configuration..."
	sudo iptables -t nat -F
    if sudo /sbin/iptables-restore < $SKYUSERHOME/firewall/iptables-secondary-no-gui; then
        echo `date +"%Y-%m-%d %T - Iptables configuration with no secondary gui only, but  was uploaded..."`| tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Iptables configuration with no secondary gui failed to load..."` | tee -a $SKYBOXLOG
        state=1
    fi

# if disable_firewalls is set to true, but no gui is set to false, allow all traffic for IPTABLES
elif [ $TESTFIREWALLD -eq '0' ] && [ $DISABLE_FIREWALLS == "true" ] && [ $DISABLE_SECONDARY_GUI == "false" ]; then
    echo "Detected IPTables, loading configuration..."
	sudo iptables -t nat -F
    if sudo /sbin/iptables-restore < $SKYUSERHOME/firewall/iptables-secondary-disable; then
        echo `date +"%Y-%m-%d %T - Iptables Disable_firewalls configuration  was uploaded..."`| tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Iptables configuration with no secondary gui failed to load..."` | tee -a $SKYBOXLOG
        state=1
    fi


# set gui and disable_firewalls is set to true, disable port 8443 and allow all traffic for IPTABLES
elif [ $TESTFIREWALLD -eq '0' ] && [ $DISABLE_FIREWALLS == "true" ] && [ $DISABLE_SECONDARY_GUI == "true" ]; then
    echo "Detected IPTables, loading configuration..."
	sudo iptables -t nat -F
    if sudo /sbin/iptables-restore < $SKYUSERHOME/firewall/iptables-secondary-no-gui-allow-all; then
        echo `date +"%Y-%m-%d %T - Iptables configuration with no secondary gui and disable all firewalls enabled was uploaded..."`| tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Iptables configuration with no secondary gui failed to load..."` | tee -a $SKYBOXLOG
        state=1
    fi

# set gui and firewalls to false, normal traffic for IPTABLES
elif [ $TESTFIREWALLD -eq '0' ] && [ $DISABLE_FIREWALLS == "false" ] && [ $DISABLE_SECONDARY_GUI == "false" ]; then
    echo "Detected IPTables, loading configuration..."
	sudo iptables -t nat -F
    if sudo /sbin/iptables-restore < $SKYUSERHOME/firewall/iptables-secondary; then
        echo `date +"%Y-%m-%d %T - Iptables configuration to  allow normal traffic was uploaded..."`| tee -a $SKYBOXLOG
    else
        echo `date +"%Y-%m-%d %T - Iptables configuration with no secondary gui failed to load..."` | tee -a $SKYBOXLOG
        state=1
    fi

else
    echo "There appears to a problem with the configuration, check the skybox_ha.conf"
    state=1
fi

# disabling task scheduler in sb_server.properties
cd $SKYBOX_HOME/server/bin/
												   
if ./settaskschedulingactivation.sh disable >/dev/null; then
        echo `date +"%Y-%m-%d %T - Task Scheduling has been disabled"` | tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
        state=0
    else
        echo `date +"%Y-%m-%d %T - ERROR: Task Scheduling has not been set to false. Please rerun the setsecondary script again."` |
        tee -a  $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
        state=1
fi

# disabling _collectors_auto_update flag in sb_server.properties
cd $SKYBOX_HOME/server/bin/
if grep -rni "enable_collectors_auto_update=true" $SKYBOX_HOME/server/conf/sb_server.properties
    then
        echo `date +"%Y-%m-%d %T - enable_collectors_auto_update flag is set to true, changing flag to false"` |
        tee -a $SKYBOX_HOME/server/log/debug/debug.log
        sed -i 's/enable_collectors_auto_update=true/enable_collectors_auto_update=false/g' $SKYBOX_HOME/server/conf/sb_server.properties
        if [ $? == 0 ]
            then
                echo `date +"%Y-%m-%d %T - enable_collectors_auto_update flag has been successfully set to false..."` |
                tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
                state=0
            else
                echo `date +"%Y-%m-%d %T - enable_collectors_auto_update flag has not been set to false, please rerun script"` |
                tee -a $SKYBOX_HOME/server/log/debug/debug.log $SKYBOXLOG
                state=1
        fi
    else
        echo `date +"%Y-%m-%d %T - enable_collectors_auto_update flag is set to false, no change needed..."` |
        tee -a $SKYBOX_HOME/server/log/debug/debug.log  $SKYBOXLOG
fi

#
# checks state variable to see if all of the scripts were ran correctly
#
if [ $state == 0 ]
then
   echo `date +"%Y-%m-%d %T - Host has been successfully set as secondary"` | tee -a $SKYBOXLOG
else
   echo `date +"%Y-%m-%d %T - Host failed to be set as secondary"` | tee -a $SKYBOXLOG
fi


# main code - stop
