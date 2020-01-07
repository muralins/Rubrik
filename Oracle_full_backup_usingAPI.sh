#!/bin/bash
#----------------------------------------------
# Updated Script By: Murali Sriram
#
################################
####### GLOBAL VARIABLES #######
################################
# This is the IP or FQND for the Rubrik Cluster
# Note: Replace the below line with correct Rubrik Cluster IP/FQDN
RUBRIK_CLUSTER=example.rubrikdemo.com

# This is the base64 encoded "user:password" string for the Rubrik Cluster
# echo -n admin:password | openssl enc -base64
# Note: Replace the below line with the HASH for an account who can login to Rubrik Cluster and has privs
MV_AUTH_HASH=bXVyYWxpLnNyaXJhbUBydWJyaWtkZW1vLmNvbTpFY1ZNQ1FIMUZ2

#----------------------------------------------
# Function to print the usage
# No Input
#----------------------------------------------
usage() {
    echo "Usage: $0 [-d <Oracle DB Name>] [-f]" 1>&2;
    exit 1;
}

# Read in the options
while getopts d:f option
do
 case "${option}"
 in
 d) ORACLE_DB_NAME=${OPTARG};;
 f) FORCE=true;;
 *) usage;;
 esac
done
shift $((OPTIND-1))

# Check and set input options
if [ -z "${ORACLE_DB_NAME}" ] ; then
    echo "Missing inputs ..."
    usage
fi

if [ -z "${FORCE}" ] ; then 
    FORCE=false
fi

# Get the database information from the Rubrik CDM and parse out the SLA and DB ids
DB_INFO=$(curl -s -k -X GET -H "Authorization: Basic ${MV_AUTH_HASH}" "https://${RUBRIK_CLUSTER}/api/internal/oracle/db?name=${ORACLE_DB_NAME}")
SLA_ID=$(echo $DB_INFO | sed 's/^.*"effectiveSlaDomainId":"\([0-9,a-f,-]*\)".*/\1/')
DB_ID=$(echo $DB_INFO  | sed 's/^.*"id":"\(OracleDatabase:::[0-9,a-f,-]*\)".*/\1/')
SLA_NAME=$(echo $DB_INFO | sed 's/^.*"effectiveSlaDomainName":"\([0-9,a-z,A-Z,_,-]*\)".*/\1/')
HOST_NAME=$(echo $DB_INFO | sed 's/^.*"standaloneHostName":"\([0-9,a-z,A-Z,.,-,_]*\)".*/\1/')
Archive_log=$(echo $DB_INFO | jq '.data[].isArchiveLogModeEnabled')

echo "DB Name   :" ${ORACLE_DB_NAME}
echo "SLA NAME  :" ${SLA_NAME}
echo "SLA ID    :" ${SLA_ID}
echo "DB ID     :" ${DB_ID}
echo "Host Name :" ${HOST_NAME}
echo "Archive Enabled:" ${Archive_log}

echo "Submitting Database Backup job now...."

# Initiate a database snapshot (backup) request
curl -k -X POST -H "Authorization: Basic ${MV_AUTH_HASH}" -H 'Content-Type: application/json' -H 'Accept: application/json' -d "{ 
   \"slaId\": \"${SLA_ID}\", 
   \"forceFullSnapshot\": ${FORCE} 
 }" "https://${RUBRIK_CLUSTER}/api/internal/oracle/db/${DB_ID}/snapshot"
echo ""
exit 0