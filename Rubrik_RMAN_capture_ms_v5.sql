prompt #Author        : Murali Sriram (murali.sriram@rubrik.com)

SET SERVEROUTPUT ON
set feedback off
set linesize 120
set pagesize 100

column FILE_NAME new_value SPOOL_FILE_NAME noprint
select 'Rubrik-RMAN-'||name||'.out' FILE_NAME from v$database;
spool &SPOOL_FILE_NAME

prompt
prompt Database Name
prompt *************

col platform_name for a25
col force_logging for a25
select name,log_mode,database_role,platform_name,force_logging from v$database;

col host_name for a40
select host_name, version_full,edition,database_type from v$instance;

prompt
prompt Database size
prompt *************

SELECT
    round(SUM(used.bytes) / 1024 / 1024 / 1024) allocated_size,
    round(SUM(used.bytes) / 1024 / 1024 / 1024) - round(free.p / 1024 / 1024 / 1024) used_size 
FROM
    (
        SELECT
            bytes
        FROM
            v$datafile
        UNION ALL
        SELECT
            bytes
        FROM
            v$tempfile
        UNION ALL
        SELECT
            bytes
        FROM
            v$log
    ) used,
    (
        SELECT
            SUM(bytes) AS p
        FROM
            dba_free_space
    ) free
GROUP BY
    free.p;

prompt
prompt Does this DB have Encryption
prompt ****************************

SELECT TABLESPACE_NAME, ENCRYPTED FROM DBA_TABLESPACES;

SELECT * FROM DBA_ENCRYPTED_COLUMNS;

prompt 
prompt Archive Log Generation rates
prompt ****************************

select trunc(completion_time) rundate
,count(*)  logswitch
,round((sum(blocks*block_size)/1024/1024/1024)) "ArchiveLogs PER DAY (GB)"
from gv$archived_log
group by trunc(completion_time)
order by 1 desc;

prompt
prompt RMAN Backup Jobs from the database
prompt **********************************

col "Start Time" for a10
col "Status" for a10
col "Type" for a14
col "In Size" for a10
col "Out Size" for a10
col "Duration" for a10
col "Input Rate per Sec" for a10
col "Output Rate per Sec" for a10

select start_time as "Start Time",
status as "Status",
input_type as "Type",
input_bytes_display as "In Size",
output_bytes_display as "Out Size",
time_taken_display as "Duration",
input_bytes_per_sec_display as "Input Rate per Sec",
output_bytes_per_sec_display as "Output Rate per Sec"
from v$rman_backup_job_details
order by start_time desc;

prompt
prompt Image Copies of DataFiles
prompt *************************
col name for a50
col tag for a20
col output_bytes_display for a20
select name, tag, output_bytes_display from v$BACKUP_COPY_DETAILS;

prompt
prompt Backup Set Copies
prompt *****************
col tag for a20
col file_types for a50
col device_type for a10
SELECT 
              F.BS_KEY,
              F.TAG,
              T.FILE_TYPES,
              F.DEVICE_TYPE, 
              F.BS_PIECES
            FROM 
              V$BACKUP_FILES F,
              (
                SELECT 
                  BS_KEY,
                  LISTAGG(FILE_TYPE, ',') WITHIN GROUP (ORDER BY FILE_TYPE) AS FILE_TYPES
                FROM
                  V$BACKUP_FILES
                WHERE 
                  FILE_TYPE != 'PIECE' AND
                  BS_KEY IS NOT NULL      
                GROUP BY BS_KEY
              ) T
            WHERE 
              NVL(F.BACKUP_TYPE, 'NULL') = 'BACKUP SET' AND 
              NVL(F.BS_STATUS, 'NULL') = 'AVAILABLE' AND
              F.FILE_TYPE = 'PIECE' AND
              F.BS_KEY = T.BS_KEY
            ORDER BY F.BS_KEY DESC;

prompt
prompt RMAN Configuration
prompt ******************

col name format a40;
col value format a50;
select name,value from gv$rman_configuration;

prompt
exit;
