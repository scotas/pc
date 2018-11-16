
------------------------------------------------------------------------------
--    Puull Connector Index Method  common types                            --
------------------------------------------------------------------------------
-- Drops
DECLARE
  TYPE obj_arr IS TABLE OF VARCHAR2(300);
  DRP_STMT VARCHAR2(4000) := 'drop ';
  obj_list obj_arr := obj_arr('public synonym pc_msg_typ','public synonym rowid_tbl','public synonym pc_error_typ',
                              'public synonym ridlist_tbl','public synonym f_info',
                              'public synonym ridlist_tbl_stats_ot','table bg_process','public synonym solrresultset',
                              'public synonym agg_tbl','public synonym agg_attributes');
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

-- CREATES
CREATE OR REPLACE TYPE f_info AS OBJECT (
  QUERIES    JSON_OBJECT_T,
  FIELDS     JSON_OBJECT_T,
  INTERVALS  JSON_OBJECT_T,
  RANGES     JSON_OBJECT_T,
  HMAPS      JSON_OBJECT_T,
  PIVOTS     JSON_OBJECT_T
) NOT PERSISTABLE
/
show errors

create or replace type pc_msg_typ as object (
  ridlist     sys.ODCIRidList,
  operation   VARCHAR2(32)
)
/
show errors

create or replace type pc_error_typ as object (
  failed_op   pc_msg_typ,
  prefix      VARCHAR2(32),
  error_msg   VARCHAR2(4000)
)
/
show errors

-- from ODCIRidList ROWID is represented as VARCHAR2(5072)
CREATE OR REPLACE TYPE rowid_tbl AS TABLE OF VARCHAR2(5072)
/
show errors


create or replace
TYPE agg_attributes AS OBJECT
      ( qryText      VARCHAR2(4000)
      , hits         NUMBER
)
/
show errors

create or replace
TYPE agg_tbl
  AS TABLE OF agg_attributes
/
show errors

CREATE OR REPLACE FUNCTION ridlist_tbl(ridlist sys.odciridlist) RETURN rowid_tbl PIPELINED AS
BEGIN
  FOR i IN 1 .. ridlist.last LOOP
    PIPE ROW(ridlist(i));
  END LOOP;
  RETURN;
END ridlist_tbl;
/
show errors

-- Code example extracted from http://www.oracle-developer.net/display.php?id=427
-- by Adrian Billington, June 2009
CREATE OR REPLACE TYPE ridlist_tbl_stats_ot AUTHID CURRENT_USER AS OBJECT (
  dummy_attribute NUMBER,
  STATIC FUNCTION ODCIGetInterfaces (p_interfaces OUT SYS.ODCIObjectList) RETURN NUMBER,
  STATIC FUNCTION ODCIStatsTableFunction (
        p_function IN  SYS.ODCIFuncInfo,
        p_stats    OUT SYS.ODCITabFuncStats,
        p_args     IN  SYS.ODCIArgDescList,
        ridlist    IN  sys.odciridlist
  ) RETURN NUMBER
);
/
show errors

-- temporary table used by jobs process
CREATE TABLE bg_process (host_name VARCHAR2(4000), port NUMBER, bg_process_name VARCHAR2(256), PRIMARY KEY (host_name, port))
/

begin
    DBMS_AQADM.CREATE_QUEUE_TABLE(queue_table        => 'ERRORS$QT',
                                  queue_payload_type => 'PC.pc_error_typ',
                                  sort_list          => 'ENQ_TIME',
                                  message_grouping   => DBMS_AQADM.NONE,
                                  compatible         => '10.2',
                                  multiple_consumers => FALSE);
    DBMS_AQADM.CREATE_QUEUE(queue_name         => 'ERRORS$Q',
                            queue_table        => 'ERRORS$QT',
                            queue_type         => DBMS_AQADM.NORMAL_QUEUE,
                            comment            => 'PushConnector Domain Index error queue');
    DBMS_AQADM.START_QUEUE(queue_name          => 'ERRORS$Q');
exception when others then
   null;
end;
/
show errors

CREATE OR REPLACE PACKAGE solrresultset AUTHID definer IS
    TYPE score_tbl IS
        TABLE OF NUMBER INDEX BY VARCHAR2(5072);
    TYPE highlighting_tbl IS
        TABLE OF VARCHAR2(32767) INDEX BY VARCHAR2(5072);
    TYPE morelikethis_tbl IS
        TABLE OF sys.odciridlist INDEX BY VARCHAR2(5072);
    j_list sys.odciridlist;            -- Resulset from Solr server
    scores score_tbl;                  -- Pre-computed scored values by rowid
    highlighting highlighting_tbl;     -- Pre-computed highlighting values by rowid
    mlt morelikethis_tbl;              -- Pre-computed mlt values by rowid
    PROCEDURE parse (
        p_docs    json_array_t,
        s_score   BOOLEAN DEFAULT true,
        n_score   NUMBER DEFAULT 1,
        p_hl      json_object_t DEFAULT NULL,
        p_ml      json_object_t DEFAULT NULL
    );

    FUNCTION gethlt (
        rid IN   VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION getmlt (
        rid IN   VARCHAR2
    ) RETURN sys.odciridlist;

    FUNCTION getscore (
        rid IN   VARCHAR2
    ) RETURN NUMBER;

    PRAGMA restrict_references ( parse, wnds, rnds, trust );
    PRAGMA restrict_references ( gethlt, wnds, rnds, trust );
    PRAGMA restrict_references ( getmlt, wnds, rnds, trust );
    PRAGMA restrict_references ( getscore, wnds, rnds, trust );
END solrresultset;
/
show errors

-- GRANTS
grant execute on pc_msg_typ to public
/
grant execute on pc_error_typ to public
/
grant execute on ridlist_tbl to public
/
grant execute on rowid_tbl to public
/
grant execute on ridlist_tbl_stats_ot to public
/
grant execute on f_info to public
/
grant select on bg_process to public
/
grant execute on agg_attributes to public
/
grant execute on agg_tbl to public
/
grant execute on solrresultset to public
/

-- public synonym
create public synonym pc_msg_typ for PC.pc_msg_typ
/
create public synonym pc_error_typ for PC.pc_error_typ
/
create public synonym ridlist_tbl for PC.ridlist_tbl
/
create public synonym rowid_tbl for PC.rowid_tbl
/
create public synonym ridlist_tbl_stats_ot for PC.ridlist_tbl_stats_ot
/
create public synonym f_info for PC.f_info
/
create public synonym agg_attributes for PC.agg_attributes
/
create public synonym agg_tbl for PC.agg_tbl
/
create public synonym solrresultset for PC.solrresultset
/
exit
