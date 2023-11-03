#!/bin/bash
set -e
printf "\033c"
###################################################################################
# Title: spd.sh
# Description: Script to check speedtest and report back to zabbix.
# Original Author: Haim Cohen 
# Updated by: Robyn Hasbach
# 10-Feb-2019
###################################################################################
#
# Requires the following to be installed
#
# speedtest-cli
# zabbix_send
# jq
#
echo "checking speedtest and report back to zabbix, please wait..."

#################
# Configuration #
#################
# Zabbix 
TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")
ZABBIX_SENDER="/usr/bin/zabbix_sender"
ZABBIX_HOST="monitor.Horror.lan" #fully qualified name
ZABBIX_SRV="192.168.1.31" # IP address of zabbix
ZABBIX_LOG="/dev/null"
ZABBIX_DATA=/tmp/zbxdata_$TIMESTAMP.log
# Speedtest
SPEEDTEST="/usr/bin/speedtest-cli"
CACHE_FILE=/tmp/speedtest_$TIMESTAMP.log

################
# internet up? #
################
if [[ "$(ping -c 1 8.8.8.8 | grep '100% packet loss' )" != "" ]]; then
    NET_UP=$(echo "Offline")
    WAN_IP=$(echo "169.254.0.1")
    PING=$(echo 0)
    SRV_NAME=$(echo "Offline")
    SRV_CITY=$(echo "Offline")
    SRV_KM=$(echo 0)
    DL_TMP=$(echo 0)
    UP_TMP=$(echo 0)
    exit 1
else
    NET_UP=$(echo "Online")
    
#################
# Generate data #
#################
speedtest --json > $CACHE_FILE

##################
# Extract fields #
##################
output=$(cat $CACHE_FILE)
    WAN_IP=$(echo "$output" | jq --raw-output '.client.ip')
    PING=$(echo "$output" | jq --raw-output '.ping')
    SRV_NAME=$(echo "$output" | jq --raw-output '.server.sponsor')
    SRV_CITY=$(echo "$output" | jq --raw-output '.server.name')
    SRV_KM=$(echo "$output" | jq --raw-output '.server.d')
    DL_TMP=$(echo "$output" | jq --raw-output '.download')
    UP_TMP=$(echo "$output" | jq --raw-output '.upload')
    
    
fi


#####################
# convert to Mbit/s #
#####################
DL=$(echo "$DL_TMP" |  awk '{ printf("%.2f\n", $1 / 1024 /1024 ) }')
UP=$(echo "$UP_TMP" |  awk '{ printf("%.2f\n", $1 / 1024 /1024 ) }')


#####################
# Write Zabbix Data #
#####################
 echo "$ZABBIX_HOST" key.download $DL >> $ZABBIX_DATA 
 echo "$ZABBIX_HOST" key.upload $UP >> $ZABBIX_DATA 
 echo "$ZABBIX_HOST" key.wan.ip $WAN_IP >> $ZABBIX_DATA 
 echo "$ZABBIX_HOST" key.ping $PING >> $ZABBIX_DATA
 echo "$ZABBIX_HOST" key.srv.name $SRV_NAME >> $ZABBIX_DATA
 echo "$ZABBIX_HOST" key.srv.city $SRV_CITY >> $ZABBIX_DATA
 echo "$ZABBIX_HOST" key.srv.km $SRV_KM >> $ZABBIX_DATA
 echo "$ZABBIX_HOST" key.net.up $NET_UP >> $ZABBIX_DATA

##########################
# zabbix sender finction #
##########################
function send_value {

      /usr/bin/zabbix_sender -z $ZABBIX_SRV -s $ZABBIX_HOST -i $ZABBIX_DATA
}

#######################
# Send data to Zabbix #
send_value
#######################
