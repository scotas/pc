set long 10000 lines 140 pages 50 timing on echo off
set serveroutput on size 1000000 
whenever SQLERROR EXIT FAILURE
DECLARE
  v_version VARCHAR2(4000);
  v_code    NUMBER;
  v_errm    VARCHAR2(4000);
BEGIN
  select banner into v_version from v$version where rownum=1;
  if (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0 OR instr(v_version,'18c')>0) then
    begin
      begin
        execute immediate 'begin DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl => ''solr.xml'', description => ''WWW solr ACL'', principal => ''PC'', is_grant => true, privilege => ''connect''); COMMIT; end;';
        dbms_lock.sleep(5);
      exception when others then
        execute immediate 'begin DBMS_NETWORK_ACL_ADMIN.DROP_ACL(acl => ''solr.xml''); COMMIT; end;';
        delete from PC.bg_process where host_name='localhost' and port = 8983;
        execute immediate 'begin DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl => ''solr.xml'', description => ''WWW solr ACL'', principal => ''PC'', is_grant => true, privilege => ''connect''); COMMIT; end;';
        dbms_lock.sleep(5);
      end;

      execute immediate 'begin DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl => ''solr.xml'', principal => ''PC'', is_grant => true, privilege => ''resolve''); COMMIT; end;';
      dbms_lock.sleep(5);
	  
      execute immediate 'begin DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(acl => ''solr.xml'', host => ''localhost'', lower_port => 8983, upper_port => 8983); COMMIT; end;';
      dbms_lock.sleep(5);
    EXCEPTION WHEN OTHERS THEN
          DBMS_OUTPUT.PUT_LINE('ERROR!');
          DBMS_OUTPUT.PUT_LINE('SQLCODE: ' || TO_CHAR(SQLCODE));
          DBMS_OUTPUT.PUT_LINE('SQLERRM: ' || SQLERRM);
    end;
  end if;
  insert into PC.bg_process (bg_process_name,host_name,port) values ('Default solr Server','localhost',8983);
  COMMIT;
END;
/
exit
