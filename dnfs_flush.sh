#!/bin/bash
# Author: Murali.Sriram@rubrik.com

export ORACLE_HOME=/u03/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=demoprod1
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_LANG=american
export NLS_DATE_FORMAT="dd-MON-YYYY hh24:mi:ss"

$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
SET SERVEROUTPUT ON
set feedback off
set heading off
set echo off
set linesize 180
set pagesize 100
set verify off

column FILE_NAME new_value SPOOL_FILE_NAME noprint
select 'Rubrik-DNFS_FLUSH-'||name||'.sql' FILE_NAME from v\$database;
spool &SPOOL_FILE_NAME
select 'exec dbms_dnfs.unmountvolume(''' || svrname ||'''' ||',' ||''''|| dirname ||''||''')' from v\$dnfs_servers
where dirname like '%sd%mount%oracle%';
spool off;
EOF

$ORACLE_HOME/bin/sqlplus / as sysdba <<EOF2
column FILE_NAME new_value SPOOL_FILE_NAME noprint
select 'Rubrik-DNFS_FLUSH-'||name||'.sql' FILE_NAME from v\$database;
@&SPOOL_FILE_NAME
EOF2

exit;


