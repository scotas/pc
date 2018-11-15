rem usage notes:
rem sqlplus sys/change_on_install@orcl @db/create-user.sql
set long 10000 lines 140 pages 50 timing on echo off
set serveroutput on size 1000000 
whenever SQLERROR EXIT FAILURE

-- drop PC users only if exists and there is no domain indexes associated
declare
  vCount NUMBER;
  plsql_block VARCHAR2(4000) := 'drop user PC cascade';
begin
  select count(*) into vCount from all_indexes where ITYP_OWNER='PC' AND (ITYP_NAME='SOLR' OR ITYP_NAME='ES' OR ITYP_NAME='HBASE' OR ITYP_NAME='CASSANDRA');
  if (vCount>0) then
    raise_application_error
        (-20101, 'There are SOLR, ElasticSearch, HBASE or CASSANDRA Domain Index created, drop them first. Aborting installation....');
  else
    select count(*) into vCount from dba_users where username='PC';
    if (vCount>0) then
      -- drop PC users
      execute immediate plsql_block;
    end if;
  end if;
end;
/

whenever SQLERROR CONTINUE

create user PC identified by PC
default tablespace users
temporary tablespace temp
quota unlimited on users
/
grant connect,resource to PC
/
grant create public synonym, drop public synonym to PC
/
grant create any trigger, drop any trigger to PC
/
grant create library to PC
/
grant create any directory to PC
/
grant create any operator, create indextype, create table to PC
/
grant select any table to PC
/
GRANT EXECUTE ON dbms_aq TO PC
/
GRANT EXECUTE ON dbms_aqadm TO PC
/
GRANT EXECUTE ON dbms_lob TO PC
/
GRANT EXECUTE ON dbms_lock TO PC
/
GRANT EXECUTE ON dbms_system TO PC
/
grant select on v_$session to PC
/
grant select on v_$sqlarea to PC
/
-- requires to use DBMS_XPLAN
grant select on V_$SQL_PLAN_STATISTICS_ALL to PC
/
grant select on V_$SQL_PLAN to PC
/
grant select on V_$SESSION to PC
/
grant select on V_$SQL_PLAN_STATISTICS_ALL to PC
/
grant select on V_$SQL to PC
/
-- debugging priv
grant DEBUG CONNECT SESSION, DEBUG ANY PROCEDURE to PC
/
-- Auto trace facilities
grant SELECT_CATALOG_ROLE to PC
/
begin
  -- AQ Role for managing QUEUE in others schemas 12cR2 required
  DBMS_AQADM.GRANT_SYSTEM_PRIVILEGE('MANAGE_ANY','PC',FALSE);
  commit;
end;
/
exit
