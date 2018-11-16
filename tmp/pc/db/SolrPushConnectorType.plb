DECLARE
  TYPE obj_arr IS TABLE OF VARCHAR2(30);
  DRP_STMT VARCHAR2(4000) := 'drop public synonym ';
  obj_list obj_arr := obj_arr('SContains','SScore','SHighlight','SMlt','Solr');
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
CREATE OR REPLACE OPERATOR SContains
  BINDING (VARCHAR2, VARCHAR2) RETURN NUMBER
  WITH INDEX CONTEXT, SCAN CONTEXT SolrPushConnector COMPUTE ANCILLARY DATA
  without column data USING SolrPushConnector.TextContains,
  (VARCHAR2, VARCHAR2, VARCHAR2) RETURN NUMBER
  WITH INDEX CONTEXT, SCAN CONTEXT SolrPushConnector COMPUTE ANCILLARY DATA
  without column data USING SolrPushConnector.TextContains,
  (CLOB, VARCHAR2) RETURN NUMBER
  WITH INDEX CONTEXT, SCAN CONTEXT SolrPushConnector COMPUTE ANCILLARY DATA
  without column data USING SolrPushConnector.TextContains,
  (CLOB, VARCHAR2, VARCHAR2) RETURN NUMBER
  WITH INDEX CONTEXT, SCAN CONTEXT SolrPushConnector COMPUTE ANCILLARY DATA
  without column data USING SolrPushConnector.TextContains,
  (sys.XMLType, VARCHAR2) RETURN NUMBER
  WITH INDEX CONTEXT, SCAN CONTEXT SolrPushConnector COMPUTE ANCILLARY DATA
  without column data USING SolrPushConnector.TextContains,
  (sys.XMLType, VARCHAR2, VARCHAR2) RETURN NUMBER
  WITH INDEX CONTEXT, SCAN CONTEXT SolrPushConnector COMPUTE ANCILLARY DATA
  without column data USING SolrPushConnector.TextContains;
show errors
/
CREATE OR REPLACE OPERATOR SScore BINDING 
  (NUMBER) RETURN NUMBER
    ANCILLARY TO SContains(VARCHAR2, VARCHAR2),
                 SContains(VARCHAR2, VARCHAR2, VARCHAR2),
                 SContains(CLOB, VARCHAR2),
                 SContains(CLOB, VARCHAR2, VARCHAR2),
                 SContains(sys.XMLType, VARCHAR2),
                 SContains(sys.XMLType, VARCHAR2, VARCHAR2)
    without column data USING SolrPushConnector.TextScore;
show errors
/
CREATE OR REPLACE OPERATOR SHighlight BINDING 
  (NUMBER) RETURN VARCHAR2
    ANCILLARY TO SContains(VARCHAR2, VARCHAR2),
                 SContains(VARCHAR2, VARCHAR2, VARCHAR2),
                 SContains(CLOB, VARCHAR2),
                 SContains(CLOB, VARCHAR2, VARCHAR2),
                 SContains(sys.XMLType, VARCHAR2),
                 SContains(sys.XMLType, VARCHAR2, VARCHAR2)
    USING SolrPushConnector.TextHighlight;
show errors
/
CREATE OR REPLACE OPERATOR SMlt BINDING 
  (NUMBER) RETURN sys.ODCIRidList
    ANCILLARY TO SContains(VARCHAR2, VARCHAR2),
                 SContains(VARCHAR2, VARCHAR2, VARCHAR2),
                 SContains(CLOB, VARCHAR2),
                 SContains(CLOB, VARCHAR2, VARCHAR2),
                 SContains(sys.XMLType, VARCHAR2),
                 SContains(sys.XMLType, VARCHAR2, VARCHAR2)
    USING SolrPushConnector.TextMlt;
show errors
/
create indextype Solr
for
SContains(varchar2, varchar2),
SContains(varchar2, varchar2, varchar2),
SContains(CLOB, varchar2),
SContains(CLOB, varchar2, varchar2),
SContains(sys.XMLType, varchar2),
SContains(sys.XMLType, varchar2, varchar2)
using SolrPushConnector
without column data
with array dml
with order by sscore(number)
with rebuild online
with local range partition
with composite index
/
grant execute on SContains to public
/
grant execute on SScore to public
/
grant execute on SHighlight to public
/
grant execute on SMlt to public
/
grant execute on Solr to public
/
create public synonym SContains for PC.SContains
/
create public synonym SScore for PC.SScore
/
create public synonym SHighlight for PC.SHighlight
/
create public synonym SMlt for PC.SMlt
/
create public synonym Solr for PC.Solr
/
exit
