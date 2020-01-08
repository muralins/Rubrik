#!/bin/bash
#----------------------------------------------
# Author: Murali.Sriram@rubrik.com
#----------------------------------------------
clear
xdate=`date +%m%d%Y_%H%M%S `
PRG=` basename $0 `
USAGE="Usage: ${PRG}"
if [ $# -gt 0 ]; then
   echo "${USAGE}"
   exit 1
fi
#----------------------------------------------
# Replace below set of variable for your environment 
#----------------------------------------------
export LOG_HOME=/home/oracle/rubrik/log
export ORACLE_SID=ebsprod
export ORACLE_HOME=/u01/app/oracle/product/19.3.0/dbhome_1

export CLUSTER_IP=shrd1-rbk01.rubrikdemo.com
export MV_ID="ManagedVolume:::1272aefe-ac07-44c0-9c3f-b8217b93236d"

export ARCH_DIR1=/backup/arch-ch0
export ARCH_DIR2=/backup/arch-ch1
###################
export CURL_URL="https://$CLUSTER_IP/api/internal/managed_volume/$MV_ID"
export LOG=$LOG_HOME/rubrik_arch_backup_$ORACLE_SID.log
export PATH=$PATH:$ORACLE_HOME/bin
export NLS_DATE_FORMAT='dd-mon-yyyy hh24:mi:ss'
BOX=`uname -a | awk '{print$2}'`
date
#----------------------------------------------
# Set Check and set lockfile
#----------------------------------------------
LOCKFILE=/tmp/$PRG.lock
if [ -f $LOCKFILE ]; then
   echo "lock file exists, exiting..."
   exit 1
else
   echo "DO NOT REMOVE, $LOCKFILE" > $LOCKFILE
fi
#----------------------------------------------
# Send the begin_snapshot command
#----------------------------------------------
#echo -n admin:password | openssl enc -base64
#bXVyYWxpLnNyaXJhbUBydWJyaWtkZW1vLmNvbTpFY1ZNQ1FIMUZ2

AUTH_HEADER="Authorization: Basic bXVyYWxpLnNyaXJhbUBydWJyaWtkZW1vLmNvbTpFY1ZNQ1FIMUZ2"	

#Intiate the log
touch $LOG

#Open Managed Volume
curl -k -X POST -H "$AUTH_HEADER" -d '{}' $CURL_URL'/begin_snapshot'

#
# RMAN Commands
#
rman nocatalog <<EOF
connect target /
set echo on;
spool log to '$LOG';
show all;
list incarnation;

run {
configure controlfile autobackup on;
configure retention policy to redundancy 1;
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COPY;

set controlfile autobackup format for device type disk to '$ARCH_DIR1/$ORACLE_SID-%F';

allocate channel ch0 device type disk format '$ARCH_DIR1/$ORACLE_SID-%U';
allocate channel ch1 device type disk format '$ARCH_DIR2/$ORACLE_SID-%U';

crosscheck archivelog all;
delete noprompt expired archivelog all;
sql 'alter system archive log current';
backup as COMPRESSED BACKUPSET archivelog all not backed up;

release channel ch0;
release channel ch1;
}
EOF
#Close Managed Volume
curl -k -X POST -H "$AUTH_HEADER" -d '{}' $CURL_URL'/end_snapshot'

rman nocatalog <<EOF
connect target /
set echo on;
spool log to '$LOG' append;
run {
delete noprompt archivelog all backed up 1 times to device type disk;
}
EOF

echo "\n\n"
echo "-----------------------------------------"
if [ $? -ne 0 ]; then
echo " "
echo "RMAN problem..."
echo "Check RMAN backups"
else
echo " "
echo "RMAN backup for $ORACLE_SID completed successfully..."
echo " "
fi
#----------------------------------------------
if [ -f $LOCKFILE ]; then
   rm $LOCKFILE
fi
#----------------------------------------------
date
#
mv $LOG $LOG_HOME/rubrik_arch_backup_$ORACLE_SID\_$xdate.log
#
exit 0

