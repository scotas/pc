---------------------------------------------------------------------------
--    Solr Push Connector Index Method  Implemented as Trusted Callouts  --
---------------------------------------------------------------------------
-- Drops
DECLARE
  stmt VARCHAR2(4000) := 'drop public synonym SolrPushConnector';
BEGIN
  execute immediate stmt;
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
/

-- drop type SolrPushConnector;

-- CREATE INDEXTYPE IMPLEMENTATION TYPE
create or replace TYPE SolrPushConnector AUTHID CURRENT_USER AS OBJECT
(
  M_TABLE      VARCHAR2(256),
  C_POSITION   INTEGER,
  NORM_SCORE   NUMBER,

  STATIC FUNCTION getIndexPrefix(ia SYS.ODCIIndexInfo) RETURN VARCHAR2,

  STATIC FUNCTION getParameter(PREFIX VARCHAR2, PARTNAME IN VARCHAR2, PARAMNAME IN VARCHAR2, DFLT IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2,

  STATIC FUNCTION TextContains(Text IN VARCHAR2, Key IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextContains(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextContains(Text IN CLOB, Key IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextContains(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextContains(Text IN XMLTYPE, Key IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextContains(Text IN XMLTYPE, Key IN VARCHAR2, Sort IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextScore(Text IN VARCHAR2, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextScore(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextScore(Text IN CLOB, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextScore(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextScore(Text IN XMLTYPE, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextScore(Text IN XMLTYPE, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER,

  STATIC FUNCTION TextHighlight(Text IN VARCHAR2, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2,

  STATIC FUNCTION TextHighlight(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2,

  STATIC FUNCTION TextHighlight(Text IN CLOB, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2,

  STATIC FUNCTION TextHighlight(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2,

  STATIC FUNCTION TextHighlight(Text IN XMLTYPE, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2,

  STATIC FUNCTION TextHighlight(Text IN XMLTYPE, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2,

  STATIC FUNCTION TextMlt(Text IN VARCHAR2, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList,

  STATIC FUNCTION TextMlt(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList,

  STATIC FUNCTION TextMlt(Text IN CLOB, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList,

  STATIC FUNCTION TextMlt(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList,

  STATIC FUNCTION TextMlt(Text IN XMLTYPE, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList,

  STATIC FUNCTION TextMlt(Text IN XMLTYPE, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList,

  STATIC FUNCTION ODCIGetInterfaces(ifclist OUT NOCOPY sys.ODCIObjectList) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexCreate(ia sys.ODCIIndexInfo, parms VARCHAR2,
                                  env sys.ODCIEnv) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexAlter(ia sys.ODCIIndexInfo, parms IN OUT NOCOPY VARCHAR2, alter_option NUMBER, env sys.ODCIEnv) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexDrop(ia sys.ODCIIndexInfo, env sys.ODCIEnv) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexTruncate(ia SYS.ODCIIndexInfo, env SYS.ODCIEnv) RETURN NUMBER,

  -- Array DML implementation --
  STATIC FUNCTION ODCIIndexDelete(ia sys.ODCIIndexInfo, ridlist sys.ODCIRidList, env sys.ODCIEnv) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexInsert(ia sys.ODCIIndexInfo, ridlist sys.ODCIRidList, env sys.ODCIEnv) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexUpdate(ia sys.ODCIIndexInfo, ridlist sys.ODCIRidList, env sys.ODCIEnv) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexExchangePartition(ia sys.ODCIIndexInfo, ia1 sys.ODCIIndexInfo, env sys.ODCIEnv)  RETURN NUMBER,

  STATIC FUNCTION ODCIIndexMergePartition(ia sys.ODCIIndexInfo, 
                                          part_name1 sys.ODCIPartInfo, 
                                          part_name2 sys.ODCIPartInfo, 
                                          parms VARCHAR2, 
                                          env sys.ODCIEnv)  RETURN NUMBER,

  STATIC FUNCTION ODCIIndexSplitPartition(ia sys.ODCIIndexInfo, 
                                          part_name1 sys.ODCIPartInfo, 
                                          part_name2 sys.ODCIPartInfo, 
                                          parms VARCHAR2, 
                                          env sys.ODCIEnv)  RETURN NUMBER,

  STATIC FUNCTION ODCIIndexStart(sctx IN OUT NOCOPY SolrPushConnector,
                                 ia SYS.ODCIIndexInfo, op SYS.ODCIPredInfo, qi sys.ODCIQueryInfo,
                                 strt number, stop number,
                                 cmpval VARCHAR2, env SYS.ODCIEnv) RETURN NUMBER,

  STATIC FUNCTION ODCIIndexStart(sctx IN OUT NOCOPY SolrPushConnector,
                                 ia SYS.ODCIIndexInfo, op SYS.ODCIPredInfo, qi sys.ODCIQueryInfo,
                                 strt number, stop number,
                                 cmpval VARCHAR2, sortval VARCHAR2, env SYS.ODCIEnv) RETURN NUMBER,

  MEMBER FUNCTION ODCIIndexFetch(SELF IN OUT NOCOPY SolrPushConnector, nrows NUMBER, rids OUT NOCOPY SYS.ODCIridlist, env SYS.ODCIEnv) RETURN NUMBER,

  MEMBER FUNCTION ODCIIndexClose(env SYS.ODCIEnv) RETURN NUMBER,

  STATIC PROCEDURE sync(index_name VARCHAR2),

  STATIC PROCEDURE sync(owner VARCHAR2, index_name VARCHAR2, part_name IN VARCHAR2 DEFAULT NULL),

  STATIC PROCEDURE syncInternal(prefix VARCHAR2, 
                                deleted sys.ODCIRidList, 
                                inserted sys.ODCIRidList),

  STATIC PROCEDURE optimize(index_name VARCHAR2),

  STATIC PROCEDURE optimize(owner VARCHAR2, index_name VARCHAR2, part_name IN VARCHAR2 DEFAULT NULL),

  STATIC PROCEDURE rebuild(index_name VARCHAR2),

  STATIC PROCEDURE rebuild(owner VARCHAR2, index_name VARCHAR2, part_name IN VARCHAR2 DEFAULT NULL),

  STATIC PROCEDURE msgCallBack(context  IN  RAW, 
                               reginfo  IN  SYS.AQ$_REG_INFO, 
                               descr    IN  SYS.AQ$_DESCRIPTOR, 
                               payload  IN  RAW,
                               payloadl IN  NUMBER),

  STATIC PROCEDURE enableCallBack(prefix VARCHAR2),
  STATIC PROCEDURE disableCallBack(prefix VARCHAR2),
  STATIC PROCEDURE enqueueChange(prefix VARCHAR2, rid VARCHAR2, operation VARCHAR2),
  STATIC PROCEDURE enqueueChange(prefix VARCHAR2, ridlist sys.ODCIRidList, operation VARCHAR2),
  STATIC PROCEDURE createTable(prefix VARCHAR2),
  STATIC PROCEDURE dropTable(prefix VARCHAR2),

  STATIC FUNCTION countHits(index_name VARCHAR2, cmpval VARCHAR2) RETURN NUMBER,

  STATIC FUNCTION countHits(owner VARCHAR2, index_name VARCHAR2, cmpval VARCHAR2) RETURN NUMBER,

  STATIC FUNCTION facet(index_name VARCHAR2,
                        Q       VARCHAR2, /* default *:* */
                        F       VARCHAR2 /* any facet Faceting Parameters encoded using URL sintax including the prefix "facet." */) RETURN f_info,

  STATIC FUNCTION facet(owner VARCHAR2, index_name VARCHAR2,
                        Q       VARCHAR2, /* default *:* */
                        F       VARCHAR2 /* any facet Faceting Parameters encoded using URL sintax including the prefix "facet." */) RETURN f_info,

  PRAGMA RESTRICT_REFERENCES (getIndexPrefix, WNDS, WNPS, RNDS, RNPS),
  PRAGMA RESTRICT_REFERENCES (getParameter, WNDS, WNPS),
  PRAGMA RESTRICT_REFERENCES (TextContains, WNDS, RNDS, TRUST),
  PRAGMA RESTRICT_REFERENCES (ODCIIndexStart, WNDS, RNDS, TRUST),
  PRAGMA RESTRICT_REFERENCES (ODCIIndexFetch, WNDS, RNDS, TRUST),
  PRAGMA RESTRICT_REFERENCES (ODCIIndexClose, WNDS, RNDS, TRUST),
  PRAGMA RESTRICT_REFERENCES (countHits, WNDS, RNDS, TRUST)
);
/
show errors


-- GRANTS
GRANT EXECUTE ON SolrPushConnector TO PUBLIC
/
create public synonym SolrPushConnector for PC.SolrPushConnector
/
exit
