rem usage notes:
rem sqlplus sys/change_on_install@orcl @db/change-deployment-server.sql connector newhost newport
set long 10000 lines 140 pages 50 timing on echo off
set serveroutput on size 1000000 

define connector=&1;
define newhost=&2;
define newport=&3;

whenever SQLERROR EXIT FAILURE

DECLARE
  v_version VARCHAR2(4000);
  v_code    NUMBER;
  v_errm    VARCHAR2(4000);
  stmt      VARCHAR2(4000);
BEGIN
  select banner into v_version from v$version where rownum=1;
  if (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0 OR instr(v_version,'18c')>0) then
    begin
      begin
        stmt := 'begin DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl => ''&connector..xml'', description => ''WWW &connector ACL'', principal => ''PC'', is_grant => true, privilege => ''connect''); end;';
        execute immediate stmt;
        dbms_lock.sleep(5);
      exception when others then
        stmt := 'begin DBMS_NETWORK_ACL_ADMIN.DROP_ACL(acl => ''&connector..xml''); end;';
        execute immediate stmt;
        delete from PC.bg_process where bg_process_name = 'Default &connector Server';
        stmt := 'begin DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl => ''&connector..xml'', description => ''WWW &connector ACL'', principal => ''PC'', is_grant => true, privilege => ''connect''); end;';
        execute immediate stmt;
        dbms_lock.sleep(5);
      end;
      stmt := 'begin DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl => ''&connector..xml'', principal => ''PC'', is_grant => true, privilege => ''resolve''); end;';
      execute immediate stmt;
      stmt := 'begin DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(acl => ''&connector..xml'', host => ''&newhost'', lower_port => &newport, upper_port => &newport); end;';
      execute immediate stmt;
      dbms_lock.sleep(5);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('ERROR!');
      DBMS_OUTPUT.PUT_LINE('SQLCODE: ' || TO_CHAR(SQLCODE));
      DBMS_OUTPUT.PUT_LINE('SQLERRM: ' || SQLERRM);
    end;
  end if;
  insert into PC.bg_process (bg_process_name,host_name,port) values ('Default &connector Server','&newhost',&newport);
  COMMIT;
END;
/


exit
