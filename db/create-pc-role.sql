rem usage notes:
rem sqlplus sys/change_on_install@orcl @db/create-lucene-role.sql
rem run on the server machine, because it use dbms_java.loadjava
set long 10000 lines 140 pages 50 timing on echo off
set serveroutput on size 1000000 

DECLARE
  stmt VARCHAR2(4000) := 'drop role PCUSER';
BEGIN
  execute immediate stmt;
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
/

create role PCUSER
/
-- required for parallel processing DBMS_PARALLEL_EXECUTE.run_task
grant create job to PCUSER
/
exit
