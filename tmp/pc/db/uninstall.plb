set long 10000 lines 140 pages 50 timing on echo off
set serveroutput on size 1000000 
DECLARE
  TYPE obj_arr IS TABLE OF VARCHAR2(300);
  DRP_STMT VARCHAR2(4000) := 'drop ';
  obj_list obj_arr := obj_arr('public synonym SContains','public synonym SScore','public synonym SHighlight',
                              'public synonym SMlt','public synonym Solr','public synonym json_dyn',
                              'indextype Solr','operator SScore','operator SHighlight','operator SContains','operator SMlt',
                              'public synonym SolrPushConnector','type SolrPushConnector');
BEGIN
  FOR I IN OBJ_LIST.FIRST..OBJ_LIST.LAST LOOP
  begin
    EXECUTE IMMEDIATE DRP_STMT||OBJ_LIST(I);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  end;
  end loop;
END;
/
DECLARE
  TYPE obj_arr IS TABLE OF VARCHAR2(300);
  DRP_STMT VARCHAR2(4000) := 'drop ';
  obj_list obj_arr := obj_arr('public synonym SolrPushConnectorAdm','package SolrPushConnectorAdm');
BEGIN
  FOR I IN OBJ_LIST.FIRST..OBJ_LIST.LAST LOOP
  begin
    EXECUTE IMMEDIATE DRP_STMT||OBJ_LIST(I);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  end;
  end loop;
END;
/
exit
