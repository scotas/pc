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
grant create job to PCUSER
/
exit
