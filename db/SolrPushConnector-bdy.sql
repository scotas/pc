-- prevent escape processing
set define off

---------------------------------------------------------------------------
--    Solr Push Connector Index Method  Implemented as Trusted Callouts  --
---------------------------------------------------------------------------

create or replace TYPE BODY SolrPushConnector IS
  static function getIndexPrefix(ia SYS.ODCIIndexInfo) return VARCHAR2 is
  begin
      return ia.IndexSchema || '.' || ia.IndexName;
  end getIndexPrefix;

  STATIC FUNCTION GETPARAMETER(PREFIX VARCHAR2, PARTNAME IN VARCHAR2, PARAMNAME IN VARCHAR2, DFLT IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    STMT VARCHAR2(4000) := 'SELECT PAR_VALUE FROM '||PREFIX||'$T WHERE ';
    RET_VAL VARCHAR2(4000) := DFLT;
  BEGIN
    IF (PARTNAME IS NULL) THEN
      EXECUTE IMMEDIATE STMT||'PAR_NAME = :1 AND ROWNUM=1' INTO RET_VAL USING PARAMNAME;
    ELSE
      EXECUTE IMMEDIATE STMT||'PART_NAME = :1 AND PAR_NAME = :2' INTO RET_VAL USING PARTNAME,PARAMNAME;
    END IF;
    return RET_VAL;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    return RET_VAL;
  end getParameter;

  static function ODCIGetInterfaces(
    ifclist out NOCOPY sys.ODCIObjectList) return number is
  begin
    ifclist := sys.ODCIObjectList(sys.ODCIObject('SYS','ODCIINDEX2'));    return sys.ODCIConst.Success;
  END ODCIGETINTERFACES;

  STATIC FUNCTION ODCIIndexCreate(IA SYS.ODCIINDEXINFO, PARMS VARCHAR2,
                                  ENV SYS.ODCIENV) RETURN NUMBER IS
    PREFIX     VARCHAR2(30) := GETINDEXPREFIX(IA);
    PART       VARCHAR2(30) := NVL(IA.INDEXPARTITION,'NONE');
    OBJ        JSON_OBJECT_T;
    KEYS       JSON_KEY_LIST;
    PAR_NAME   VARCHAR2(128);
    PAR_VALUE  VARCHAR2(4000);
    REQ        UTL_HTTP.REQ;
  BEGIN
    -- Dump the SQL statement.
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexCreate>>>>>');
    --DBMS_OUTPUT.PUT_LINE(PARMS);
    --SYS.ODCIINDEXINFODUMP(IA);
    --SYS.ODCIENVDUMP(ENV);
    IF (ENV.CALLPROPERTY = ODCICONST.FINALCALL) THEN
        RETURN SYS.ODCICONST.SUCCESS;
    END IF;
    IF (ENV.CALLPROPERTY IS NULL) OR
       (ENV.CALLPROPERTY = SYS.ODCICONST.FIRSTCALL) OR
       (ENV.CALLPROPERTY = SYS.ODCICONST.FINALCALL) THEN
         CREATETABLE(PREFIX);
         PushConnectorAdm.CREATEQUEUE(PREFIX);
    END IF;
    IF (ENV.CALLPROPERTY IS NULL) THEN
      IF (PARMS IS NOT NULL) THEN
        OBJ := JSON_OBJECT_T.parse(PARMS);
      ELSE
        OBJ := JSON_OBJECT_T();
      END IF;
      --DBMS_OUTPUT.put_line(OBJ.to_string);
      OBJ.put('Index owner',IA.INDEXSCHEMA);
      OBJ.put('Index name',IA.INDEXNAME);
      OBJ.put('Table owner',IA.INDEXCOLS(1).TABLESCHEMA);
      OBJ.put('Table name',IA.INDEXCOLS(1).TABLENAME);
      OBJ.put('Indexed column',IA.INDEXCOLS(1).COLNAME);
      OBJ.put('Indexed column type',IA.INDEXCOLS(1).COLTYPENAME);
      IF (NOT OBJ.has('Updater')) THEN
        IF (OBJ.has('Searcher')) THEN
          OBJ.put('Updater',OBJ.get('Searcher'));
        ELSE
          OBJ.put('Updater','localhost@8983');
        END IF;
      END IF;
      IF (NOT OBJ.has('Searcher')) THEN
        OBJ.put('Searcher',OBJ.get('Updater'));
      END IF;
      KEYS := OBJ.get_keys;
      FOR I IN 1..KEYS.COUNT LOOP
        EXECUTE IMMEDIATE 'INSERT INTO '||PREFIX||'$T VALUES(:1,:2,:3)' USING PART,KEYS(i),OBJ.get_String(KEYS(i));
      END LOOP;
    END IF;
    IF (OBJ.has('SyncMode') AND OBJ.get_String('SyncMode') = 'OnLine') THEN
      ENABLECALLBACK(PREFIX);
    END IF;
    REBUILD(IA.INDEXSCHEMA,IA.INDEXNAME,NULL);
    IF (OBJ.has('LogLevel') AND OBJ.get_String('LogLevel') = 'INFO') THEN
      sys.dbms_system.ksdwrt(1,'Index created: '||GETPARAMETER(PREFIX,PART,'Index name'));
    END IF;
    RETURN SYS.ODCICONST.SUCCESS;
  END ODCIIndexCreate;

  STATIC FUNCTION ODCIIndexAlter(ia sys.ODCIIndexInfo, parms IN OUT NOCOPY VARCHAR2, alter_option NUMBER, env sys.ODCIEnv) RETURN NUMBER is
    PREFIX     VARCHAR2(30) := GETINDEXPREFIX(IA);
    OBJ        JSON_OBJECT_T;
    KEYS       JSON_KEY_LIST;
    PART       VARCHAR2(30) := NVL(IA.INDEXPARTITION,'NONE');
    SYNC_MODE  VARCHAR2(32) := GETPARAMETER(PREFIX,PART,'SyncMode');
    LOG_LEVEL  VARCHAR2(32) := NVL(GETPARAMETER(PREFIX,PART,'LogLevel'),'WARNING');
  BEGIN
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexAlter>>>>>');
    --SYS.ODCIINDEXINFODUMP(IA);
    --SYS.ODCIENVDUMP(ENV);
    --DBMS_OUTPUT.PUT_LINE('alter_option: '||alter_option);
    IF (LOG_LEVEL = 'INFO') THEN
      sys.dbms_system.ksdwrt(1,'Index alter with parms: '||parms);
    END IF;
    IF (PARMS IS NOT NULL) THEN
      OBJ := JSON_OBJECT_T.parse(parms);
      KEYS := OBJ.get_keys;
      FOR I IN 1..KEYS.COUNT LOOP
        BEGIN
          IF (SUBSTR(KEYS(i),1,1) = '~') THEN
            EXECUTE IMMEDIATE 'DELETE FROM '||PREFIX||'$T WHERE PART_NAME = :1 AND PAR_NAME = :2' USING PART,SUBSTR(KEYS(i),2);
          ELSE
            EXECUTE IMMEDIATE 'INSERT INTO '||PREFIX||'$T VALUES(:1,:2,:3)' USING PART,KEYS(i),OBJ.get_String(KEYS(i));
          END IF;
        EXCEPTION WHEN OTHERS THEN
          -- parameter exits
          EXECUTE IMMEDIATE 'UPDATE '||PREFIX||'$T SET PAR_VALUE = :1 WHERE PART_NAME = :2 AND PAR_NAME = :3' USING OBJ.get_String(KEYS(i)),PART,KEYS(i);
        END;
      END LOOP;
    END IF;
    IF (OBJ.has('SyncMode')) THEN
       IF (OBJ.get_String('SyncMode') = 'OnLine' AND SYNC_MODE = 'Deferred') THEN
          --DBMS_OUTPUT.PUT_LINE('ENABLECALLBACK: '||PREFIX);
          ENABLECALLBACK(PREFIX);
       ELSE IF (OBJ.get_String('SyncMode') = 'Deferred' AND SYNC_MODE = 'OnLine') THEN
              --DBMS_OUTPUT.PUT_LINE('DISABLECALLBACK: '||PREFIX);
              DISABLECALLBACK(PREFIX);
            ELSE
              NULL;
            END IF;
       END IF;
    END IF;
    IF (ALTER_OPTION = ODCIConst.AlterIndexRebuild) THEN
      REBUILD(IA.INDEXSCHEMA,IA.INDEXNAME,NULL);
    END IF;
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexAlter>>>>>');
    RETURN SYS.ODCICONST.SUCCESS;
  END ODCIIndexAlter;

  STATIC FUNCTION ODCIIndexDrop(ia sys.ODCIIndexInfo, env sys.ODCIEnv) RETURN NUMBER is
    PREFIX     VARCHAR2(30) := GETINDEXPREFIX(IA);
    PART       VARCHAR2(30) := NVL(IA.INDEXPARTITION,'NONE');
    OBJ        JSON_OBJECT_T;
    REQ        UTL_HTTP.REQ;
    SYNC_MODE  VARCHAR2(32) := GETPARAMETER(PREFIX,PART,'SyncMode');
    LOG_LEVEL  VARCHAR2(32) := NVL(GETPARAMETER(PREFIX,PART,'LogLevel'),'WARNING');
  BEGIN
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexDrop>>>>>');
    --SYS.ODCIINDEXINFODUMP(IA);
    --SYS.ODCIENVDUMP(ENV);
    --DBMS_OUTPUT.PUT_LINE('Dropping index: '||IA.INDEXNAME);
    IF (LOG_LEVEL = 'INFO') THEN
      sys.dbms_system.ksdwrt(1,'Dropping index: '||IA.INDEXNAME);
    END IF;
    OBJ := JSON_OBJECT_T.parse('{"delete": { "query":"solridx:'||PREFIX||'"}, "commit":{"softCommit":"false"}}');
    begin
      IF (LOG_LEVEL = 'INFO') THEN
         sys.dbms_system.ksdwrt(1,'Solr delete by query: http://'||
                                              replace(NVL(GETPARAMETER(PREFIX,PART,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                              '/update/json?wt=json&ident=on');
      END IF;
      REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                              replace(NVL(GETPARAMETER(PREFIX,PART,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                              '/update/json?wt=json&ident=on','POST',OBJ);
      OBJ := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
    exception when others then
      sys.dbms_system.ksdwrt(1,'ODCIIndexDrop Exception');
      sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
    end;
    DROPTABLE(PREFIX);
    PushConnectorAdm.PURGUEQUEUE(PREFIX);
    IF (SYNC_MODE = 'OnLine') THEN
      DISABLECALLBACK(PREFIX);
    END IF;
    PushConnectorAdm.DROPQUEUE(PREFIX);
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexDrop>>>>>');
    RETURN SYS.ODCICONST.SUCCESS;
  END ODCIIndexDrop;

  STATIC FUNCTION ODCIIndexTruncate(ia SYS.ODCIIndexInfo, env SYS.ODCIEnv) RETURN NUMBER is
    PREFIX VARCHAR2(30) := GETINDEXPREFIX(IA);
    PART VARCHAR2(30) := NVL(IA.INDEXPARTITION,'NONE');
    LOG_LEVEL  VARCHAR2(32) := NVL(GETPARAMETER(PREFIX,PART,'LogLevel'),'WARNING');
  BEGIN
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexTruncate>>>>>');
    --SYS.ODCIINDEXINFODUMP(IA);
    --SYS.ODCIENVDUMP(ENV);
    IF (LOG_LEVEL = 'INFO') THEN
      sys.dbms_system.ksdwrt(1,'Truncating index: '||IA.INDEXNAME);
    END IF;
    PushConnectorAdm.PURGUEQUEUE(PREFIX);
    REBUILD(IA.INDEXSCHEMA,IA.INDEXNAME,NULL);
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexTruncate>>>>>');
    RETURN SYS.ODCICONST.SUCCESS;
  END ODCIIndexTruncate;

  STATIC FUNCTION ODCIIndexExchangePartition(ia sys.ODCIIndexInfo, ia1 sys.ODCIIndexInfo, env sys.ODCIEnv)  RETURN NUMBER is
  BEGIN
    -- TODO nothing to do here
    RETURN SYS.ODCICONST.SUCCESS;
  END ODCIIndexExchangePartition;

  STATIC FUNCTION ODCIIndexMergePartition(ia sys.ODCIIndexInfo,
                                          part_name1 sys.ODCIPartInfo,
                                          part_name2 sys.ODCIPartInfo,
                                          parms VARCHAR2,
                                          env sys.ODCIEnv)  RETURN NUMBER is
  BEGIN
    -- TODO nothing to do here
    RETURN SYS.ODCICONST.SUCCESS;
  END ODCIIndexMergePartition;

  STATIC FUNCTION ODCIIndexSplitPartition(ia sys.ODCIIndexInfo,
                                          part_name1 sys.ODCIPartInfo,
                                          part_name2 sys.ODCIPartInfo,
                                          parms VARCHAR2,
                                          env sys.ODCIEnv)  RETURN NUMBER is
  BEGIN
    -- TODO nothing to do here
    RETURN SYS.ODCICONST.SUCCESS;
  END ODCIIndexSplitPartition;

  STATIC FUNCTION TextContains(Text IN VARCHAR2, Key IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextContains(Text,Key,null,indexctx,sctx,scanflg);
  end TextContains;

  STATIC FUNCTION TextContains(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                               INDEXCTX IN SYS.ODCIINDEXCTX, SCTX IN OUT NOCOPY SolrPushConnector, SCANFLG IN NUMBER) RETURN NUMBER IS
    IA             SYS.ODCIINDEXINFO := INDEXCTX.INDEXINFO;
    PREFIX         VARCHAR2(255) := IA.INDEXSCHEMA || '.' || IA.INDEXNAME;
    PART           VARCHAR2(30)  := NVL(IA.INDEXPARTITION,'NONE');
    LOG_LEVEL      VARCHAR2(32)  := NVL(GETPARAMETER(PREFIX,PART,'LogLevel'),'WARNING');
    S_NORM_SCORE   VARCHAR2(32)  := NVL(GETPARAMETER(PREFIX,PART,'NormalizeScore'),'false');
    NORM_SCORE     NUMBER := 1;
    REQ            UTL_HTTP.REQ;
    Q              VARCHAR2(32767);
    OBJ            JSON_OBJECT_T;
    li_arr         JSON_ARRAY_T;
  begin
     -- TODO, do the http call here
     --DBMS_OUTPUT.PUT_LINE('TextContains>>>>>');
     --SYS.ODCIINDEXINFODUMP(ia);
     --DBMS_OUTPUT.PUT_LINE('rid: '||INDEXCTX.RID);
     --DBMS_OUTPUT.PUT_LINE('scanflg: '||SCANFLG);
     --DBMS_OUTPUT.PUT_LINE('Text: '||Text);
     --DBMS_OUTPUT.PUT_LINE('Key: '||KEY);
     IF (SCANFLG = 1 AND SCTX IS NOT NULL) THEN
       SCTX := null;
       return 0; -- close operation
     END IF;
     IF (SCANFLG = 2 AND INDEXCTX.RID IS NULL) THEN
       RETURN 0;
     END IF;
     IF (ia IS NULL AND SCANFLG > 0) THEN
       RETURN 0;  -- no domain index bound to this column
     END IF;
     IF (SCTX IS NULL) THEN
       -- prepare call
       Q := UTL_URL.ESCAPE('rows=1000&fl=rowid score&q=(solridx:'||PREFIX||') AND ('||KEY||')',false,'UTF8');
       IF (LOG_LEVEL = 'INFO') THEN
         sys.dbms_system.ksdwrt(1,'Solr qry: http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,PART,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                              '/select/?wt=json&omitHeader=true&'||Q);
       END IF;
       REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,PART,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                              '/select/?wt=json&omitHeader=true&'||Q,'GET',OBJ);
       OBJ := PushConnectorAdm.REQ_2_JSON_object(REQ);
       OBJ := OBJ.get_Object('response'); -- response
       li_arr := OBJ.get_Array('docs');
        IF (S_NORM_SCORE = 'true' AND OBJ.get_Number('numFound') > 0) THEN
            NORM_SCORE := 1 / OBJ.get_Number('maxScore');
            --DBMS_OUTPUT.PUT_LINE('Normalized Score: '||NORM_SCORE);
        END IF;
       SolrResultSet.parse(li_arr,true,norm_score,null,null);
       SCTX := SolrPushConnector(GETPARAMETER(PREFIX,PART,'Table owner')||'.'||GETPARAMETER(PREFIX,PART,'Table name'),1,1);
     END IF;
     return SolrResultSet.getScore(INDEXCTX.RID);
  end TextContains;

  STATIC FUNCTION TextContains(Text IN CLOB, Key IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextContains(Text,Key,null,indexctx,sctx,scanflg);
  end TextContains;

  STATIC FUNCTION TextContains(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     -- TODO, do the http call here
     return 1;
  end TextContains;

  STATIC FUNCTION TextContains(Text IN XMLType, Key IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextContains(Text,Key,null,indexctx,sctx,scanflg);
  end TextContains;

  STATIC FUNCTION TextContains(Text IN XMLTYPE, Key IN VARCHAR2, Sort IN VARCHAR2,
                               indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     -- TODO, do the http call here
     return 1;
  end TextContains;

  STATIC FUNCTION TextScore(Text IN VARCHAR2, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextScore(Text,Key,null,indexctx,sctx,scanflg);
  end TextScore;

  STATIC FUNCTION TextScore(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                            INDEXCTX IN SYS.ODCIINDEXCTX, SCTX IN OUT NOCOPY SolrPushConnector, SCANFLG IN NUMBER) RETURN NUMBER IS
  BEGIN
     -- TODO, do the http call here
     IF (SCANFLG IS NOT NULL) THEN
       RETURN 0;
     END IF;
     return SolrResultSet.getScore(INDEXCTX.RID);
  end TextScore;

  STATIC FUNCTION TextScore(Text IN CLOB, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextScore(Text,Key,null,indexctx,sctx,scanflg);
  end TextScore;

  STATIC FUNCTION TextScore(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextScore('',Key,null,indexctx,sctx,scanflg);
  end TextScore;

  STATIC FUNCTION TextScore(Text IN XMLType, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextScore(Text,Key,null,indexctx,sctx,scanflg);
  end TextScore;

  STATIC FUNCTION TextScore(Text IN XMLType, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN NUMBER is
  begin
     return TextScore('',Key,null,indexctx,sctx,scanflg);
  end TextScore;

  STATIC FUNCTION TextHighlight(Text IN VARCHAR2, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2 is
  begin
     return TextHighlight(Text,Key,null,indexctx,sctx,scanflg);
  end TextHighlight;

  STATIC FUNCTION TextHighlight(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                            INDEXCTX IN SYS.ODCIINDEXCTX, SCTX IN OUT NOCOPY SolrPushConnector, SCANFLG IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
     -- TODO, do the http call here
     IF (SCANFLG IS NOT NULL) THEN
       RETURN '';
     END IF;
     return SolrResultSet.getHlt(INDEXCTX.RID);
  end TextHighlight;

  STATIC FUNCTION TextHighlight(Text IN CLOB, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2 is
  BEGIN
     return TextHighlight('',Key,indexctx,sctx,scanflg);
  end TextHighlight;

  STATIC FUNCTION TextHighlight(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2 is
  begin
     return TextHighlight('',Key,indexctx,sctx,scanflg);
  end TextHighlight;

  STATIC FUNCTION TextHighlight(Text IN XMLType, Key IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2 is
  BEGIN
     return TextHighlight('',Key,indexctx,sctx,scanflg);
  end TextHighlight;

  STATIC FUNCTION TextHighlight(Text IN XMLTYPE, Key IN VARCHAR2, Sort IN VARCHAR2,
                            indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN VARCHAR2 is
  begin
     return TextHighlight('',Key,indexctx,sctx,scanflg);
  end TextHighlight;

  STATIC FUNCTION TextMlt(Text IN VARCHAR2, Key IN VARCHAR2,
                          indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList is
  begin
     return TextMlt(Text,Key,null,indexctx,sctx,scanflg);
  end TextMlt;

  STATIC FUNCTION TextMlt(Text IN VARCHAR2, Key IN VARCHAR2, Sort IN VARCHAR2,
                          INDEXCTX IN SYS.ODCIINDEXCTX, SCTX IN OUT NOCOPY SOLRPUSHCONNECTOR, SCANFLG IN NUMBER) RETURN SYS.ODCIRIDLIST IS
  BEGIN
     -- TODO, do the http call here
     IF (SCANFLG IS NOT NULL) THEN
       RETURN SYS.ODCIRIDLIST();
     END IF;
     return SolrResultSet.getMlt(INDEXCTX.RID);
  end TextMlt;

  STATIC FUNCTION TextMlt(Text IN CLOB, Key IN VARCHAR2,
                          indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList is
  BEGIN
     return TextMlt('',Key,indexctx,sctx,scanflg);
  end TextMlt;

  STATIC FUNCTION TextMlt(Text IN CLOB, Key IN VARCHAR2, Sort IN VARCHAR2,
                          indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList is
  begin
     return TextMlt('',Key,indexctx,sctx,scanflg);
  end TextMlt;

  STATIC FUNCTION TextMlt(Text IN XMLType, Key IN VARCHAR2,
                          indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList is
  BEGIN
     return TextMlt('',Key,indexctx,sctx,scanflg);
  end TextMlt;

  STATIC FUNCTION TextMlt(Text IN XMLTYPE, Key IN VARCHAR2, Sort IN VARCHAR2,
                          indexctx IN sys.ODCIIndexCtx, sctx IN OUT NOCOPY SolrPushConnector, scanflg IN NUMBER) RETURN sys.ODCIRidList is
  begin
     return TextMlt('',Key,indexctx,sctx,scanflg);
  end TextMlt;

  STATIC FUNCTION ODCIIndexStart(sctx IN OUT NOCOPY SolrPushConnector,
                                 ia SYS.ODCIIndexInfo, op SYS.ODCIPredInfo, qi sys.ODCIQueryInfo,
                                 strt number, stop number,
                                 cmpval VARCHAR2, env SYS.ODCIEnv) RETURN NUMBER is
  BEGIN
     -- pass sortval as null
     return ODCIIndexStart(sctx,ia,op,qi,strt,stop,cmpval,null,env);
  end ODCIIndexStart;

  STATIC FUNCTION ODCIIndexStart(sctx IN OUT NOCOPY SolrPushConnector,
                                 ia SYS.ODCIIndexInfo, op SYS.ODCIPredInfo, qi sys.ODCIQueryInfo,
                                 strt number, stop number,
                                 cmpval VARCHAR2, sortval VARCHAR2, env SYS.ODCIEnv) RETURN NUMBER is
    OBJ            JSON_OBJECT_T;
    PREFIX         VARCHAR2(255) := IA.INDEXSCHEMA || '.' || IA.INDEXNAME;
    PART           VARCHAR2(30)  := NVL(IA.INDEXPARTITION,'NONE');
    LOG_LEVEL      VARCHAR2(32)  := NVL(GETPARAMETER(PREFIX,PART,'LogLevel'),'WARNING');
    S_NORM_SCORE   VARCHAR2(32)  := NVL(GETPARAMETER(PREFIX,PART,'NormalizeScore'),'false');
    J_LIST         SYS.ODCIRIDLIST;
    REQ            UTL_HTTP.REQ;
    Q              VARCHAR2(32767);
    MAIN_TBL       VARCHAR2(256)  := GETPARAMETER(PREFIX,PART,'Table owner')||'.'||GETPARAMETER(PREFIX,PART,'Table name');
    STMT           VARCHAR2(2000) := 'SELECT rowid FROM '
                     || MAIN_TBL
                     || ' L$ORIG$TBL, TABLE(:1) L$PIPE$TBL WHERE L$ORIG$TBL.rowid = L$PIPE$TBL.COLUMN_VALUE';
    IN_STR_POS     INTEGER;
    PAGINATION     VARCHAR2(200);
    qry            varchar2(32767);
    R_START        INTEGER;
    N_ROWS         PLS_INTEGER;
    SORT_STR       VARCHAR2(4000) := 'score desc'; -- natural sort score desc
    FLD_STR        VARCHAR2(128)  := 'fl=rowid';
    H_STR          VARCHAR2(128)  := null; -- no highlighting
    M_STR          VARCHAR2(128)  := null; -- no more like this
    START_TIME     NUMBER := DBMS_UTILITY.GET_TIME;
    NORM_SCORE     NUMBER := 1;
    docs_arr       JSON_ARRAY_T;
    mlt_obj        JSON_OBJECT_T;
    hlt_obj        JSON_OBJECT_T;
    m_score        boolean := false;
  begin
    -- TODO analyze arguments call for the existense of sscore, shighlight, and others ancillary operators
    -- check for the sorting argument
    -- evaluate for the existence of FIRST_ROWS hint
    -- performs the HTTP call and store the result on Json var
    --    analyze if is better to store the utl_http result and parse the Json value in fetch
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexStart init>>>>>');
    --SYS.ODCIINDEXINFODUMP(IA);
    --SYS.ODCIENVDUMP(ENV);
    --SYS.ODCIQUERYINFODUMP(QI);
    --SYS.ODCIPREDINFODUMP(OP);
    IF QI.ANCOPS IS NOT NULL AND QI.ANCOPS.COUNT > 0 THEN
      --DBMS_OUTPUT.PUT_LINE('Ancillary Operators  ');
      FOR I IN QI.ANCOPS.FIRST..QI.ANCOPS.LAST LOOP
       --dbms_output.put_line('   Name : '||
       --                     qi.AncOps(i).ObjectName);
       --dbms_output.put_line('   Schema :'||
       --                     QI.ANCOPS(I).OBJECTSCHEMA);
       IF (QI.ANCOPS(I).OBJECTNAME = 'SSCORE') THEN
         FLD_STR := 'fl=rowid score';
         m_score := true;
       END IF;
       IF (QI.ANCOPS(I).OBJECTNAME = 'SHIGHLIGHT') THEN
         H_STR := '&hl=true&hl.fl='||NVL(GETPARAMETER(PREFIX,PART,'HighlightColumn'),GETPARAMETER(PREFIX,PART,'DefaultColumn'));
       END IF;
       IF (QI.ANCOPS(I).OBJECTNAME = 'SMLT') THEN
         M_STR := '&mlt=true&mlt.mindf=1&mlt.mintf=1&mlt.fl='||NVL(GETPARAMETER(PREFIX,PART,'MltColumn'),GETPARAMETER(PREFIX,PART,'DefaultColumn'));
       END IF;
      END LOOP;
    END IF;
    IN_STR_POS := INSTR(CMPVAL,'rownum:[');
    IF (IN_STR_POS = 1) THEN -- pagination information
       QRY := substr(cmpval,INSTR(cmpval,'] AND ')+6);
       -- inline pagination
       PAGINATION := SUBSTR(CMPVAL,9);
       PAGINATION := SUBSTR(PAGINATION,1,INSTR(PAGINATION,'] AND ')-1);
       IN_STR_POS := INSTR(PAGINATION,' TO ');
       R_START := TO_NUMBER(SUBSTR(PAGINATION,1,IN_STR_POS))-1;
       N_ROWS  := TO_NUMBER(SUBSTR(PAGINATION,IN_STR_POS+4))-R_START;
    ELSE -- no pagination information in query
       R_START := 0;
       IF (BITAND(QI.FLAGS, ODCICONST.QUERYFIRSTROWS) > 0) THEN
         -- override n_rows if FIRST_ROWS OPTIMIZER HINT IS PRESENT
         N_ROWS  := 1000;
       END IF;
       IF (BITAND(QI.FLAGS, ODCICONST.QUERYALLROWS) > 0) THEN
         N_ROWS  := 2000;
       ELSE
         N_ROWS  := 10;
       END IF;
       QRY := CMPVAL;
    END IF;
    IF (SORTVAL IS NULL) THEN
      IF (BITAND(QI.FLAGS, ODCICONST.QUERYSORTASC) > 0) THEN
         SORT_STR := 'score asc';
      END IF;
      IF (BITAND(QI.FLAGS, ODCICONST.QuerySortDesc) > 0) THEN
         SORT_STR := 'score desc';
      END IF;
    ELSE
      SORT_STR := SORTVAL;
    END IF;
    Q := UTL_URL.ESCAPE(FLD_STR||H_STR||M_STR||'&start='||R_START||'&rows='||N_ROWS||'&sort='||SORT_STR||'&q=(solridx:'||PREFIX||') AND ('||QRY||')',false,'UTF8');
    --DBMS_OUTPUT.PUT_LINE('Q : '||Q);
    --DBMS_OUTPUT.PUT_LINE('R_START : '||R_START);
    --DBMS_OUTPUT.PUT_LINE('N_ROWS : '||N_ROWS);
    START_TIME := DBMS_UTILITY.GET_TIME;
    IF (LOG_LEVEL = 'INFO') THEN
         sys.dbms_system.ksdwrt(1,'Solr qry: http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,PART,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                              '/select/?wt=json&omitHeader=true&df='||
                                              NVL(GETPARAMETER(PREFIX,PART,'DefaultColumn'),'text')||'&'||Q);
    END IF;
    REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,PART,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                              '/select/?wt=json&omitHeader=true&df='||
                                              NVL(GETPARAMETER(PREFIX,PART,'DefaultColumn'),'text')||'&'||Q,'GET',OBJ);
    -- DBMS_OUTPUT.PUT_LINE('REQ complete : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
    OBJ := PUSHCONNECTORADM.REQ_2_JSON_object(REQ);
    -- DBMS_OUTPUT.PUT_LINE('OBJ parsed time: '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
    IF (H_STR IS NOT NULL) THEN
      hlt_obj := OBJ.get_Object('highlighting');
    END IF;
    -- DBMS_OUTPUT.PUT_LINE('S_HIGHLIGHTING completed : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
    IF (M_STR IS NOT NULL) THEN
      mlt_obj := OBJ.get_Object('moreLikeThis'); -- More Like This
    END IF;
    -- DBMS_OUTPUT.PUT_LINE('S_MLT completed : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
    OBJ := OBJ.get_Object('response'); -- response
    -- DBMS_OUTPUT.PUT_LINE('response completed : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
    --DBMS_OUTPUT.PUT_LINE('OBJ response: '||OBJ.to_string);
    docs_arr := OBJ.get_Array('docs');
    IF (m_score AND S_NORM_SCORE = 'true' AND OBJ.get_Number('numFound') > 0) THEN
      NORM_SCORE := 1 / OBJ.get_Number('maxScore');
      --DBMS_OUTPUT.PUT_LINE('Normalized Score: '||NORM_SCORE);
    END IF;
    SolrResultSet.parse(docs_arr,m_score,norm_score,hlt_obj,mlt_obj);
    SCTX := SOLRPUSHCONNECTOR(MAIN_TBL,1,NORM_SCORE);
    --DBMS_OUTPUT.PUT_LINE('ODCIIndexStart end >>>>>');
    RETURN SYS.ODCICONST.SUCCESS;
  exception when others then
    sys.dbms_system.ksdwrt(1,'ODCIIndexStart Exception');
    sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
    return SYS.ODCICONST.ERROR;
  end ODCIIndexStart;


  MEMBER FUNCTION ODCIINDEXFETCH(SELF IN OUT NOCOPY SolrPushConnector, NROWS NUMBER, RIDS OUT NOCOPY SYS.ODCIRIDLIST, ENV SYS.ODCIENV) RETURN NUMBER IS
    TYPE         RidCurTyp IS REF CURSOR;
    RID_CV       RIDCURTYP;
    RLIST        SYS.ODCIRIDLIST := SYS.ODCIRIDLIST();
    IDX          INTEGER         := 1;
    START_TIME   NUMBER          := DBMS_UTILITY.GET_TIME;
    RID          UROWID;
    DONE         BOOLEAN         := FALSE;
    STMT         VARCHAR2(2000)  := 'SELECT rid_a FROM (select column_value rid_a,rownum rn_a from TABLE(:1)),(select rowid rid_b from '
               || M_TABLE
               || ') WHERE rid_a = rid_b order by rn_a';
  begin
     --EXECUTE IMMEDIATE stmt BULK COLLECT INTO rids using trids;
     -- select table_name, owner, index, etc. etc
     -- fetch the content of the http call an parse as Json
     -- filter deleted rowids
     --DBMS_OUTPUT.PUT_LINE('ODCIIndexFetch end>>>>>');
     --DBMS_OUTPUT.PUT_LINE('SolrResultSet.j_list.count:' || SolrResultSet.j_list.count);
     IF (C_POSITION>SolrResultSet.j_list.count) THEN
       RETURN SYS.ODCICONST.SUCCESS;
     END IF;
     START_TIME := DBMS_UTILITY.GET_TIME;
     WHILE NOT DONE LOOP
       IF IDX > NROWS THEN
         DONE := TRUE;
       ELSE
         IF C_POSITION <= SolrResultSet.j_list.count THEN
            RLIST.EXTEND;
            RLIST(IDX) := SolrResultSet.j_list(C_POSITION);
            --DBMS_OUTPUT.PUT_LINE(' RLIST(IDX) : '||RLIST(IDX));
            C_POSITION := C_POSITION + 1;
            IDX := IDX + 1;
         ELSE
            DONE := TRUE;
         END if;
      END IF;
     END LOOP;
     --DBMS_OUTPUT.PUT_LINE('RLIST complete : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
     --DBMS_OUTPUT.PUT_LINE('rlist.COUNT : '||RLIST.COUNT||' stmt: '||STMT);
     -- prevents ORA-06502: PL/SQL: numeric or value error: Bulk Bind on 10g
     RIDS := SYS.ODCIRIDLIST();
     idx := 1;
     OPEN rid_cv FOR STMT USING RLIST;
     loop
       FETCH rid_cv INTO RID;
       EXIT WHEN rid_cv%NOTFOUND;
       RIDS.EXTEND;
       RIDS(IDX) := RID;
       IDX := IDX + 1;
     end loop;
     --DBMS_OUTPUT.PUT_LINE('RIDS.('||RIDS.COUNT||')');
     CLOSE RID_CV;
     --DBMS_OUTPUT.PUT_LINE('RIDS complete : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
     --EXECUTE IMMEDIATE STMT USING RLIST RETURNING BULK COLLECT INTO RIDS ;
     --DBMS_OUTPUT.PUT_LINE('ODCIIndexFetch end>>>>>');
     return sys.ODCICONST.SUCCESS;
  exception when others then
    sys.dbms_system.ksdwrt(1,'ODCIIndexFetch Exception');
    sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
    return sys.ODCICONST.ERROR;
  end ODCIIndexFetch;

  MEMBER FUNCTION ODCIIndexClose(env SYS.ODCIEnv) RETURN NUMBER is
    CNUM       INTEGER;
  BEGIN
     -- free objects, close http call
     --DBMS_OUTPUT.PUT_LINE('ODCIIndexClose>>>>>');
     --SYS.ODCIENVDUMP(ENV);
     --DBMS_OUTPUT.PUT_LINE('ODCIIndexClose>>>>>');
     RETURN SYS.ODCICONST.SUCCESS;
  EXCEPTION WHEN OTHERS THEN
     sys.dbms_system.ksdwrt(1,'ODCIIndexClose Exception');
     sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
     return sys.ODCICONST.ERROR;
  END ODCIIndexClose;

  static procedure msgCallBack(context  IN  RAW,
                               reginfo  IN  SYS.AQ$_REG_INFO,
                               descr    IN  SYS.AQ$_DESCRIPTOR,
                               payload  IN  RAW,
                               payloadl IN  NUMBER) is
    dequeue_options     dbms_aq.dequeue_options_t;
    enqueue_options     dbms_aq.enqueue_options_t;
    message_properties  dbms_aq.message_properties_t;
    message_handle      RAW(16);
    message             PC.pc_msg_typ;
    prefix              VARCHAR2(400) := utl_raw.cast_to_varchar2(context);
    v_code              NUMBER;
    v_errm              varchar2(4000);
    lock_handle         VARCHAR2(128);
    dummy               PLS_INTEGER;
    begin
      -- start the MEP (mutually exclusive part)
      dbms_lock.allocate_unique(prefix,lock_handle);
      dummy := dbms_lock.request(lock_handle,dbms_lock.x_mode,dbms_lock.maxwait,true);
      -- get the consumer name and msg_id from the descriptor
      dequeue_options.msgid         := descr.msg_id;
      dequeue_options.consumer_name := descr.consumer_name;
      dequeue_options.delivery_mode := dbms_aq.persistent;
      dequeue_options.visibility    := dbms_aq.on_commit;
      dequeue_options.wait          := dbms_aq.no_wait;
      begin
        dbms_aq.dequeue(queue_name        =>     descr.queue_name,
                      dequeue_options     =>     dequeue_options,
                      message_properties  =>     message_properties,
                      payload             =>     message,
                      msgid               =>     message_handle);
        case
        when (message.operation = 'insert' OR message.operation = 'update') then
           syncInternal(prefix,sys.ODCIRidList(),message.ridlist);
        when (message.operation = 'delete') then
           syncInternal(prefix,message.ridlist,sys.ODCIRidList());
        when (message.operation = 'rebuild') then
            rebuild(prefix);
        WHEN (MESSAGE.OPERATION = 'optimize') THEN
            optimize(prefix);
        end case;
        -- release locks
        commit;
      exception when others then
         ROLLBACK;  -- undo changes
         sys.dbms_system.ksdwrt(1,'msgCallBack Exception, ROLLBACK');
         sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
      end;
      dummy := dbms_lock.release(lock_handle);
  end msgCallBack;

  static procedure enableCallBack(prefix VARCHAR2) is
      reginfo             sys.aq$_reg_info;
      reginfolist         sys.aq$_reg_info_list;
  begin
      reginfo := sys.aq$_reg_info(prefix||'$Q',
                                DBMS_AQ.NAMESPACE_AQ,
                                'plsql://SolrPushConnector.msgCallBack',
                                utl_raw.cast_to_raw(prefix));
    reginfolist := sys.aq$_reg_info_list(reginfo);
    sys.dbms_aq.register(reginfolist, 1);
  end enableCallBack;

  static procedure disableCallBack(prefix VARCHAR2) is
      reginfo             sys.aq$_reg_info;
      reginfolist         sys.aq$_reg_info_list;
  begin
      reginfo := sys.aq$_reg_info(prefix||'$Q',
                                DBMS_AQ.NAMESPACE_AQ,
                                'plsql://SolrPushConnector.msgCallBack',
                                utl_raw.cast_to_raw(prefix));
    reginfolist := sys.aq$_reg_info_list(reginfo);
    sys.dbms_aq.unregister(reginfolist, 1);
  end disableCallBack;

  static procedure enqueueChange(prefix VARCHAR2, rid VARCHAR2, operation VARCHAR2) is
  begin
      enqueueChange(prefix,sys.ODCIRidList(rid),operation);
  end enqueueChange;

  static procedure enqueueChange(prefix VARCHAR2, ridlist sys.odciridlist, operation VARCHAR2) is
      enqueue_options     DBMS_AQ.enqueue_options_t;
      message_properties  DBMS_AQ.message_properties_t;
      message_handle      RAW(16);
      message             PC.pc_msg_typ;
  begin
      message := PC.pc_msg_typ(ridlist,operation);
      enqueue_options.delivery_mode := dbms_aq.persistent;
      enqueue_options.visibility    := dbms_aq.on_commit;
      message_properties.exception_queue := prefix||'$QE';
      dbms_aq.enqueue(queue_name         => prefix||'$Q',
                      enqueue_options    => enqueue_options,
                      message_properties => message_properties,
                      payload            => message,
                      msgid              => message_handle);
  end enqueueChange;

  -- Array DML version --
  static function ODCIIndexInsert(ia sys.ODCIIndexInfo, ridlist sys.ODCIRidList, env sys.ODCIEnv) return NUMBER is
  begin
     enqueueChange(getIndexPrefix(ia),ridlist,'insert');
     return sys.ODCICONST.SUCCESS;
  end ODCIIndexInsert;

  static function ODCIIndexUpdate(ia sys.ODCIIndexInfo, ridlist sys.odciridlist, env sys.ODCIEnv) return NUMBER is
  begin
     enqueueChange(getIndexPrefix(ia),ridlist,'update');
     return sys.ODCICONST.SUCCESS;
  end ODCIIndexUpdate;

  static function ODCIIndexDelete(ia sys.ODCIIndexInfo, ridlist sys.odciridlist, env sys.ODCIEnv) return NUMBER is
  begin
     enqueueChange(getIndexPrefix(ia),ridlist,'delete');
     return sys.ODCICONST.SUCCESS;
  end ODCIIndexDelete;

  static procedure sync(index_name VARCHAR2) is
    index_schema VARCHAR2(30);
    idx_name VARCHAR2(30) := index_name;
    is_part varchar2(3);
    par_degree number;
    v_version VARCHAR2(4000);
  begin
    select banner into v_version from v$version where rownum=1;
    SELECT OWNER,PARTITIONED,DEGREE INTO INDEX_SCHEMA,IS_PART,PAR_DEGREE FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME;
    IF (IS_PART = 'YES' AND (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0  OR instr(v_version,'18c')>0)) THEN
      if (PAR_DEGREE > 1 AND (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0  OR instr(v_version,'18c')>0)) then
        EXECUTE IMMEDIATE 'run_in_parallel('''||INDEX_SCHEMA||''','''||IDX_NAME||''','||PAR_DEGREE||',''SYNC_PARTITION'')';
      else
        FOR P IN (SELECT PARTITION_NAME FROM ALL_IND_PARTITIONS  WHERE INDEX_OWNER=INDEX_SCHEMA AND INDEX_NAME=IDX_NAME) LOOP
           SYNC(INDEX_SCHEMA,INDEX_NAME,P.PARTITION_NAME);
        end loop;
      end if;
    ELSE
      SYNC(INDEX_SCHEMA,INDEX_NAME);
    end if;
    exception when no_data_found then
      RAISE_APPLICATION_ERROR
      (-20101, 'Index not found: '||idx_name);
    when too_many_rows then
      INDEX_SCHEMA := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
      SELECT PARTITIONED,DEGREE INTO IS_PART,PAR_DEGREE FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME and OWNER=INDEX_SCHEMA;
      IF (IS_PART = 'YES') THEN
        if (PAR_DEGREE > 1 AND (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0  OR instr(v_version,'18c')>0)) then
          EXECUTE IMMEDIATE 'run_in_parallel('''||INDEX_SCHEMA||''','''||IDX_NAME||''','||PAR_DEGREE||',''SYNC_PARTITION'')';
        else
          FOR P IN (SELECT PARTITION_NAME FROM ALL_IND_PARTITIONS  WHERE INDEX_OWNER=INDEX_SCHEMA AND INDEX_NAME=IDX_NAME) LOOP
             SYNC(INDEX_SCHEMA,INDEX_NAME,P.PARTITION_NAME);
          end loop;
        end if;
      ELSE
        SYNC(INDEX_SCHEMA,INDEX_NAME);
      END IF;
  end sync;

  static procedure sync(owner VARCHAR2, index_name VARCHAR2, part_name IN VARCHAR2 DEFAULT NULL) is
    deleted                     sys.odciridlist := sys.ODCIRidList();
    inserted                    sys.odciridlist := sys.ODCIRidList();
    dequeue_options             DBMS_AQ.dequeue_options_t;
    message_properties          DBMS_AQ.message_properties_t;
    message_handle              RAW(16);
    message                     PC.pc_msg_typ;
    message_no_data             PC.pc_msg_typ;
    NO_MESSAGES                 EXCEPTION;
    END_OF_FETCH                EXCEPTION;
    prefix                      VARCHAR2(255) := owner || '.' || index_name;
    BatchCount                  INTEGER := NVL(GetParameter(prefix,part_name,'BatchCount'),32767);
    dummy                       PLS_INTEGER;
    lock_handle                 VARCHAR2(128);
    PRAGMA EXCEPTION_INIT (end_of_fetch, -25228);
    PRAGMA EXCEPTION_INIT (no_messages, -25235);
  begin
    -- make sure that we have write access to OJVMDirectory storage during the process
    -- EXECUTE IMMEDIATE 'lock table '||prefix||'$T in exclusive mode';
    dbms_lock.allocate_unique(prefix,lock_handle);
    dummy := dbms_lock.request(lock_handle,dbms_lock.x_mode,dbms_lock.maxwait,true);
    dequeue_options.wait         := DBMS_AQ.NO_WAIT;
    dequeue_options.navigation   := DBMS_AQ.FIRST_MESSAGE;
    dequeue_options.dequeue_mode := DBMS_AQ.LOCKED;
    dequeue_options.delivery_mode := dbms_aq.persistent;
    dequeue_options.visibility    := dbms_aq.on_commit;
    LOOP
       DBMS_AQ.DEQUEUE(
          queue_name         => prefix||'$Q',
          dequeue_options    => dequeue_options,
          message_properties => message_properties,
          payload            => message,
          msgid              => message_handle);
       if (message.operation = 'delete') then
         -- put ARRAY DML rids into deleted list
         for i in 1 .. message.ridlist.last loop
              deleted.extend;
              deleted(deleted.last) := message.ridlist(i);
         end loop;
       else 
            -- if is not delete op, must be insert/update
            -- put ARRAY DML rids into inserted list
            for i in 1 .. message.ridlist.last loop
              inserted.extend;
              inserted(inserted.last) := message.ridlist(i);
            end loop;
       end if;
       -- counter is bigger than BatchCount parameter send to Solr
       if (inserted.last>=BatchCount or deleted.last>=BatchCount) then
         syncInternal(prefix,deleted,inserted);
         deleted := sys.ODCIRidList();
         inserted := sys.ODCIRidList();
       end if;
       dequeue_options.dequeue_mode := dbms_aq.REMOVE_NODATA;
       dequeue_options.msgid := message_handle;
       dequeue_options.deq_condition := '';
       dbms_aq.dequeue(
                  queue_name         => prefix||'$Q',
                  dequeue_options    => dequeue_options,
                  message_properties => message_properties,
                  payload            => message_no_data,
                  msgid              => message_handle);
       dequeue_options.dequeue_mode := DBMS_AQ.LOCKED;
       dequeue_options.msgid := NULL;
       dequeue_options.navigation := dbms_aq.NEXT_MESSAGE;
    END LOOP;
    EXCEPTION
      WHEN no_messages OR end_of_fetch THEN
        if (deleted.count>0 OR inserted.count>0) then
          syncInternal(prefix,deleted,inserted);
        end if;
        dummy := dbms_lock.release(lock_handle);
  end sync;

  static procedure syncInternal(prefix VARCHAR2,
                                deleted sys.ODCIRidList,
                                inserted sys.ODCIRidList) IS
    OBJ        JSON_OBJECT_T;
    DEL_OP     JSON_ARRAY_T  := JSON_ARRAY_T();
    REQ        UTL_HTTP.REQ;
    FULL_COLLECT_STMT VARCHAR2(32767);
    SELECT_STMT       VARCHAR2(32767);
    TBLS              VARCHAR2(256);
    -- collect parameters values without partition information
    COMMIT_ONS        VARCHAR2(256)  := NVL(GETPARAMETER(PREFIX,NULL,'CommitOnSync'),'false');
    WSEARCH           VARCHAR2(10)   := NVL(GETPARAMETER(PREFIX,NULL,'WaitSearcher'),'true');
    EDELETES          VARCHAR2(10)   := NVL(GETPARAMETER(PREFIX,NULL,'ExpungeDeletes'),'false');
    SOFT_COMMT        VARCHAR2(10)   := NVL(GETPARAMETER(PREFIX,NULL,'SoftCommit'),'false');
    EXTRA_TBLS        VARCHAR2(256)  := GETPARAMETER(PREFIX,NULL,'ExtraTabs');
    EXTRA_COLS        VARCHAR2(4000) := GETPARAMETER(PREFIX,NULL,'ExtraCols');
    WHERE_COND        VARCHAR2(4000) := GETPARAMETER(PREFIX,NULL,'WhereCondition');
    MAIN_TBL          VARCHAR2(256)  := GETPARAMETER(PREFIX,NULL,'Table owner')||'.'||GETPARAMETER(PREFIX,NULL,'Table name');
    ALL_COLS          VARCHAR2(4000);
    INCLUDE_MC        VARCHAR2(32)   := NVL(GETPARAMETER(PREFIX,NULL,'IncludeMasterColumn'),'true');
    M_COLUMN          VARCHAR2(32)   := GETPARAMETER(PREFIX,NULL,'Indexed column');
    LOG_LEVEL         VARCHAR2(32)   := NVL(GETPARAMETER(PREFIX,NULL,'LogLevel'),'WARNING');
  BEGIN
    IF (DELETED.COUNT = 0 AND INSERTED.COUNT = 0) THEN
      OBJ := JSON_OBJECT_T();
      IF (COMMIT_ONS = 'true') THEN
        OBJ.PUT('commit',JSON_OBJECT_T('{ "softCommit":'||SOFT_COMMT||', "waitSearcher":'||WSEARCH||', "expungeDeletes":'||EDELETES||' }'));
        IF (LOG_LEVEL = 'INFO') THEN
          sys.dbms_system.ksdwrt(1,'Solr commit: http://'||
                                 REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Updater'),'localhost@8983'),'@',':')||'/'||
                                 NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                 '/update/json?wt=json&ident=on');
          sys.dbms_system.ksdwrt(1,'Commit options: '||obj.to_string);
        END IF;
        begin
          REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                                REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Updater'),'localhost@8983'),'@',':')||'/'||
                                                NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                                '/update/json?wt=json&ident=on','POST',OBJ);
          OBJ := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
          commit;
        exception when others then
          rollback;
          PushConnectorAdm.AQ_ERROR(sys.ODCIRidList(),'commit',prefix);
        end;
      end if;
      RETURN;
    END IF;
    IF (DELETED.COUNT>0) THEN
      OBJ := JSON_OBJECT_T();
      FOR I IN 1..DELETED.COUNT LOOP
        DEL_OP.append(DELETED(I));
      END LOOP;
      OBJ.put('delete',DEL_OP);
      IF (INSERTED.COUNT = 0 AND COMMIT_ONS = 'true') THEN
        OBJ.PUT('commit',JSON_OBJECT_T('{ "softCommit":'||SOFT_COMMT||', "waitSearcher":'||WSEARCH||', "expungeDeletes":'||EDELETES||' }'));
        IF (LOG_LEVEL = 'INFO') THEN
          sys.dbms_system.ksdwrt(1,'Delete command: '||obj.to_string);
        END IF;
      end if;
      IF (LOG_LEVEL = 'INFO') THEN
         sys.dbms_system.ksdwrt(1,'Solr delete: http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/update/json?wt=json&ident=on with '||DELETED.COUNT||' rows to delete');
      END IF;
      begin
        REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/update/json?wt=json&ident=on','POST',OBJ);
        OBJ := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
        commit;
      exception when others then
        rollback;
        PushConnectorAdm.AQ_ERROR(deleted,'delete',prefix);
      end;
    END IF;
    IF (INSERTED.COUNT>0) THEN
      IF (EXTRA_COLS IS NOT NULL) THEN
        ALL_COLS := '''rowid'' value ''''||L$MT.rowid , ''solridx'' value '''||PREFIX||''', '||EXTRA_COLS;
      ELSE
        ALL_COLS := '''rowid'' value ''''||L$MT.rowid , ''solridx'' value '''||PREFIX||'''';
      END IF;
      IF (INCLUDE_MC = 'true') THEN
        ALL_COLS := ALL_COLS||','''||M_COLUMN||''' value L$MT.'||M_COLUMN;
      END IF;
      IF (INSERTED.COUNT = 1) THEN
        IF (EXTRA_TBLS IS NOT NULL) THEN
          TBLS := MAIN_TBL||' L$MT,'||EXTRA_TBLS||' ';
        ELSE
          TBLS := MAIN_TBL||' L$MT ';
        END IF;
        IF (WHERE_COND IS NOT NULL) THEN
          TBLS := TBLS || ' where L$MT.rowid='''||inserted(1)||''' AND ('||WHERE_COND||')';
        ELSE
          TBLS := TBLS || ' where L$MT.rowid='''||inserted(1)||'''';
        END IF;
        SELECT_STMT := 'select json_object('||ALL_COLS||' returning CLOB) L$MT$R from '||TBLS;
        full_collect_stmt :=
'DECLARE
  DOC    JSON_OBJECT_T;
  ADD_OP CLOB           := '' '';
  ARGS   VARCHAR2(32767) := ''wt=json&ident=on'';
  REQ    UTL_HTTP.REQ;
BEGIN
    JSON_DYN.streamList(add_op,:1);
';
    IF (COMMIT_ONS = 'true') THEN -- add commit command
      FULL_COLLECT_STMT := FULL_COLLECT_STMT||'
    ARGS := ARGS||''&commit=true&softCommit='||SOFT_COMMT||'&waitSearcher='||WSEARCH||'&expungeDeletes='||EDELETES||''';';
    END IF;
    FULL_COLLECT_STMT := FULL_COLLECT_STMT||'
    begin
      REQ := PushConnectorAdm.CREATEREQUEST(''http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/update/json?''||ARGS,''POST'',ADD_OP);
      DOC := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
      commit;
    exception when others then
         rollback;
         PushConnectorAdm.AQ_ERROR(sys.ODCIRidList('''||inserted(1)||'''),''insert'','''||prefix||''');
         RETURN;
    end;
end;';
        IF (LOG_LEVEL = 'INFO') THEN
          --sys.dbms_system.ksdwrt(1,'Executing: '||FULL_COLLECT_STMT);
          sys.dbms_system.ksdwrt(1,'Selecting one row for insertion using: '||SELECT_STMT);
        END IF;
        EXECUTE IMMEDIATE FULL_COLLECT_STMT USING SELECT_STMT;
      ELSE -- optimized code for multiple rows insertion
        IF (EXTRA_TBLS IS NOT NULL) THEN
          TBLS := MAIN_TBL||' L$MT,'||PREFIX||'$C C,'||EXTRA_TBLS||' ';
        ELSE
          TBLS := MAIN_TBL||' L$MT,'||PREFIX||'$C C ';
        END IF;
        IF (WHERE_COND IS NOT NULL) THEN
          TBLS := TBLS || ' where L$MT.rowid=C.rid AND ('||WHERE_COND||')';
        ELSE
          TBLS := TBLS || ' where L$MT.rowid=C.rid';
        END IF;
        SELECT_STMT := 'select json_object('||ALL_COLS||' returning CLOB) L$MT$R from '||TBLS;
        FULL_COLLECT_STMT :=
'DECLARE
  RIDS   SYS.ODCIRIDLIST;
  DOC    JSON_OBJECT_T;
  ADD_OP CLOB           := '' '';
  ARGS   VARCHAR2(32767) := ''wt=json&ident=on'';
  REQ    UTL_HTTP.REQ;
BEGIN
    INSERT INTO '||prefix||'$C (SELECT * FROM TABLE(:1));
    JSON_DYN.streamList(add_op,:2);
';
    IF (COMMIT_ONS = 'true') THEN -- add commit command
      FULL_COLLECT_STMT := FULL_COLLECT_STMT||'
    ARGS := ARGS||''&commit=true&softCommit='||SOFT_COMMT||'&waitSearcher='||WSEARCH||'&expungeDeletes='||EDELETES||''';';
    END IF;
    FULL_COLLECT_STMT := FULL_COLLECT_STMT||'
    begin
      REQ := PushConnectorAdm.CREATEREQUEST(''http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/update/json?''||ARGS,''POST'',ADD_OP);
      DOC := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
      commit;
    exception when others then
         rollback;
         PushConnectorAdm.AQ_ERROR(:1,''insert'','''||prefix||''');
         RETURN;
    end;
end;';
        IF (LOG_LEVEL = 'INFO') THEN
          --sys.dbms_system.ksdwrt(1,'Executing: '||FULL_COLLECT_STMT);
          sys.dbms_system.ksdwrt(1,'Selecting rows('||INSERTED.count||') for insertion using: '||SELECT_STMT);
        END IF;
        EXECUTE IMMEDIATE FULL_COLLECT_STMT USING INSERTED,SELECT_STMT;
      END IF;
    END IF;
    COMMIT;
  end syncInternal;

  static procedure optimize(index_name VARCHAR2) is
    index_schema VARCHAR2(30);
    idx_name VARCHAR2(30) := index_name;
    is_part varchar2(3);
    par_degree number;
    v_version VARCHAR2(4000);
  begin
    select banner into v_version from v$version where rownum=1;
    SELECT OWNER,PARTITIONED,DEGREE INTO INDEX_SCHEMA,IS_PART,PAR_DEGREE FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME;
    IF (IS_PART = 'YES' AND (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0  OR instr(v_version,'18c')>0)) THEN
      EXECUTE IMMEDIATE 'run_in_parallel('''||INDEX_SCHEMA||''','''||IDX_NAME||''','||PAR_DEGREE||',''OPTIMIZE_PARTITION'')';
    ELSE
      OPTIMIZE(INDEX_SCHEMA,INDEX_NAME);
    end if;
    exception when no_data_found then
      RAISE_APPLICATION_ERROR
      (-20101, 'Index not found: '||idx_name);
    when too_many_rows then
      INDEX_SCHEMA := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
      SELECT PARTITIONED,DEGREE INTO IS_PART,PAR_DEGREE FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME and OWNER=INDEX_SCHEMA;
      IF (IS_PART = 'YES' AND (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0  OR instr(v_version,'18c')>0)) THEN
        EXECUTE IMMEDIATE 'run_in_parallel('''||INDEX_SCHEMA||''','''||IDX_NAME||''','||PAR_DEGREE||',''OPTIMIZE_PARTITION'')';
      ELSE
        OPTIMIZE(INDEX_SCHEMA,INDEX_NAME);
      END IF;
  end optimize;

  static procedure optimize(owner VARCHAR2, index_name VARCHAR2, part_name IN VARCHAR2 DEFAULT NULL) is
    prefix     VARCHAR2(255) := OWNER || '.' || INDEX_NAME;
    OBJ        JSON_OBJECT_T;
    REQ        UTL_HTTP.REQ;
    LOG_LEVEL  VARCHAR2(32)  := NVL(GETPARAMETER(PREFIX,NULL,'LogLevel'),'WARNING');
  begin
    sync(owner,index_name,part_name); -- process pending changes first
    -- waitFlush is not compatible with LucidWorksEnterprise
    OBJ := JSON_OBJECT_T('{"optimize": { "waitSearcher":false }}');
    IF (LOG_LEVEL = 'INFO') THEN
         sys.dbms_system.ksdwrt(1,'Solr optimize: http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,PART_NAME,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART_NAME,'SolrBase'),'solr')||
                                              '/update/json?wt=json&ident=on');
    END IF;
    begin
      REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,PART_NAME,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART_NAME,'SolrBase'),'solr')||
                                              '/update/json?wt=json&ident=on','POST',OBJ);
      OBJ := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
      commit;
    exception when others then
         rollback;
         PushConnectorAdm.AQ_ERROR(sys.ODCIRidList(),'optimize',prefix);
         RETURN;
    end;
  end optimize;

  static procedure rebuild(index_name VARCHAR2) is
    index_schema VARCHAR2(30);
    idx_name VARCHAR2(30) := index_name;
    is_part varchar2(3);
    par_degree number;
    v_version VARCHAR2(4000);
  begin
    select banner into v_version from v$version where rownum=1;
    SELECT OWNER,PARTITIONED,DEGREE INTO INDEX_SCHEMA,IS_PART,PAR_DEGREE FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME;
    IF (IS_PART = 'YES' AND (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0  OR instr(v_version,'18c')>0)) THEN
      EXECUTE IMMEDIATE 'run_in_parallel('''||INDEX_SCHEMA||''','''||IDX_NAME||''','||PAR_DEGREE||',''REBUILD_PARTITION'')';
    ELSE
      REBUILD(INDEX_SCHEMA,INDEX_NAME);
    end if;
    exception when no_data_found then
      RAISE_APPLICATION_ERROR
      (-20101, 'Index not found: '||idx_name);
    when too_many_rows then
      INDEX_SCHEMA := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
      SELECT PARTITIONED,DEGREE INTO IS_PART,PAR_DEGREE FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME and OWNER=INDEX_SCHEMA;
      IF (IS_PART = 'YES' AND (instr(v_version,'11g')>0 OR instr(v_version,'12c')>0  OR instr(v_version,'18c')>0)) THEN
        EXECUTE IMMEDIATE 'run_in_parallel('''||INDEX_SCHEMA||''','''||IDX_NAME||''','||PAR_DEGREE||',''REBUILD_PARTITION'')';
      ELSE
        REBUILD(INDEX_SCHEMA,INDEX_NAME);
      END IF;
  end rebuild;

  STATIC PROCEDURE REBUILD(OWNER VARCHAR2, INDEX_NAME VARCHAR2, PART_NAME IN VARCHAR2 DEFAULT NULL) IS
    PREFIX            VARCHAR2(4000) := OWNER || '.' || INDEX_NAME;
    PART              VARCHAR2(4000) := NVL(PART_NAME,'NONE');
    OBJ               JSON_OBJECT_T;
    REQ               UTL_HTTP.REQ;
    FULL_STMT         VARCHAR2(32767);
    SELECT_STMT       VARCHAR2(32767);
    TBLS              VARCHAR2(4000);
    EXTRA_TBLS        VARCHAR2(4000) := GETPARAMETER(PREFIX,PART,'ExtraTabs');
    EXTRA_COLS        VARCHAR2(4000) := GETPARAMETER(PREFIX,PART,'ExtraCols');
    WHERE_COND        VARCHAR2(4000) := GETPARAMETER(PREFIX,PART,'WhereCondition');
    MAIN_TBL          VARCHAR2(4000) := GETPARAMETER(PREFIX,PART,'Table owner')||'.'||GETPARAMETER(PREFIX,PART,'Table name');
    COMMIT_ONS        VARCHAR2(4000) := NVL(GETPARAMETER(PREFIX,PART,'CommitOnSync'),'false');
    WSEARCH           VARCHAR2(10)   := NVL(GETPARAMETER(PREFIX,PART,'WaitSearcher'),'true');
    EDELETES          VARCHAR2(10)   := NVL(GETPARAMETER(PREFIX,PART,'ExpungeDeletes'),'false');
    SOFT_COMMT        VARCHAR2(10)   := NVL(GETPARAMETER(PREFIX,PART,'SoftCommit'),'false');
    SYNC_MODE         VARCHAR2(32)   := NVL(GETPARAMETER(PREFIX,PART,'SyncMode'),'Deferred');
    INCLUDE_MC        VARCHAR2(32)   := NVL(GETPARAMETER(PREFIX,PART,'IncludeMasterColumn'),'true');
    M_COLUMN          VARCHAR2(32)   := GETPARAMETER(PREFIX,PART,'Indexed column');
    ALL_COLS          VARCHAR2(4000);
    V_LIMIT           INTEGER        := NVL(GETPARAMETER(PREFIX,PART,'BatchCount'),170);
    LOG_LEVEL         VARCHAR2(32)   := NVL(GETPARAMETER(PREFIX,PART,'LogLevel'),'WARNING');
  begin
    -- use PC's storage table as exclusive lock
    -- EXECUTE IMMEDIATE 'lock table '||prefix||'$T in exclusive mode';
    OBJ := JSON_OBJECT_T('{"delete": { "query":"solridx:'||prefix||'"}, "commit":{"softCommit":"'||SOFT_COMMT||'","waitSearcher":"'||WSEARCH||'","expungeDeletes":"'||EDELETES||'"}}');
    REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                          REPLACE(NVL(GETPARAMETER(PREFIX,PART,'Updater'),'localhost@8983'),'@',':')||'/'||
                                          NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                          '/update/json?wt=json&ident=on','POST',OBJ);
    OBJ := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
    IF (SYNC_MODE = 'Deferred') THEN
      IF (EXTRA_TBLS IS NOT NULL) THEN
        TBLS := MAIN_TBL||' L$MT,'||PREFIX||'$C C,'||EXTRA_TBLS||' ';
      ELSE
        TBLS := MAIN_TBL||' L$MT,'||PREFIX||'$C C ';
      END IF;
      IF (WHERE_COND IS NOT NULL) THEN
        TBLS := TBLS || ' where L$MT.rowid=C.rid AND ('||WHERE_COND||')';
      ELSE
        TBLS := TBLS || ' where L$MT.rowid=C.rid';
      END IF;
      IF (EXTRA_COLS IS NOT NULL) THEN
        ALL_COLS := '''rowid'' value ''''||L$MT.rowid , ''solridx'' value '''||PREFIX||''', '||EXTRA_COLS;
      ELSE
        ALL_COLS := '''rowid'' value ''''||L$MT.rowid , ''solridx'' value '''||PREFIX||'''';
      END IF;
      IF (INCLUDE_MC = 'true') THEN
        ALL_COLS := ALL_COLS||','''||M_COLUMN||''' value L$MT.'||M_COLUMN;
      END IF;
      SELECT_STMT := 'select json_object('||ALL_COLS||' returning CLOB) L$MT$R from '||TBLS;
      --DBMS_OUTPUT.PUT_LINE('SELECT_STMT: '||SELECT_STMT);
      FULL_STMT :=
'DECLARE
  CURSOR C1 IS SELECT ROWID FROM '||MAIN_TBL||';
  RIDS   SYS.ODCIRIDLIST;
  DOC    JSON_OBJECT_T;
  ADD_OP CLOB          := '' '';
  ARGS   VARCHAR2(32767);
  REQ    UTL_HTTP.REQ;
BEGIN
  OPEN C1;
  LOOP
    ARGS := ''wt=json&ident=on'';
    FETCH C1 BULK COLLECT INTO RIDS LIMIT :1;
    EXIT WHEN RIDS.COUNT = 0;
    INSERT INTO '||prefix||'$C (SELECT * FROM TABLE(RIDS));
    JSON_DYN.streamList(add_op,:2);
';
    IF (COMMIT_ONS = 'true') THEN -- add commit command
      FULL_STMT := FULL_STMT||'
    ARGS := ARGS||''&commit=true&softCommit='||SOFT_COMMT||'&waitSearcher='||WSEARCH||'&expungeDeletes='||EDELETES||''';';
    END IF;
    FULL_STMT := FULL_STMT||'
    begin
      REQ := PushConnectorAdm.CREATEREQUEST(''http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,PART,'Updater'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,PART,'SolrBase'),'solr')||
                                              '/update/json?''||ARGS,''POST'',ADD_OP);
      DOC := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
      commit;
    exception when others then
         rollback;
         PushConnectorAdm.AQ_ERROR(RIDS,''insert'','''||prefix||''');
         RETURN;
    end;
  END LOOP;
  CLOSE C1;
end;';
    IF (LOG_LEVEL = 'INFO') THEN
          --sys.dbms_system.ksdwrt(1,'Executing: '||FULL_STMT);
          sys.dbms_system.ksdwrt(1,'Selecting rows ('||V_LIMIT||' per batch) for insertion using: '||SELECT_STMT);
    END IF;
    EXECUTE IMMEDIATE FULL_STMT USING V_LIMIT,SELECT_STMT;
  ELSE
      FULL_STMT := '
DECLARE
  CURSOR c1 IS select rowid from '||MAIN_TBL||';
  RIDS SYS.ODCIRIDLIST;
BEGIN
  OPEN c1;
  LOOP
    FETCH c1 BULK COLLECT INTO RIDS LIMIT :1;
    EXIT WHEN RIDS.COUNT = 0;
    SolrPushConnector.enqueueChange('''||prefix||''',RIDS,''insert'');
    commit;
  END LOOP;
  CLOSE c1;
END;';
    -- SELECT STMT IS NOT REQUIRED HERE
    IF (LOG_LEVEL = 'INFO') THEN
          sys.dbms_system.ksdwrt(1,'Enqueuing rows ('||V_LIMIT||' per batch) for insertion using: select rowid from '||MAIN_TBL);
    END IF;
    EXECUTE IMMEDIATE FULL_STMT USING V_LIMIT;
  END IF;
  END REBUILD;

  static procedure createTable(prefix VARCHAR2) is
    v_version VARCHAR2(4000);
    current_schema VARCHAR2(30);
  begin
      select banner into v_version from v$version where rownum=1;
      EXECUTE IMMEDIATE
'create table '||PREFIX||'$T (
    PART_NAME          VARCHAR2(30),
    PAR_NAME           VARCHAR2(128),
    PAR_VALUE         VARCHAR2(4000))';
      EXECUTE IMMEDIATE
'create global temporary table '||PREFIX||'$C (
    RID              UROWID) on commit delete rows';
        EXECUTE IMMEDIATE
'alter table '||prefix||'$T add primary key (PART_NAME,PAR_NAME)';
  end createTable;

  static procedure dropTable(prefix VARCHAR2) is
  BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE '||PREFIX||'$C FORCE';
      EXECUTE IMMEDIATE 'DROP TABLE '||prefix||'$T FORCE';
  end dropTable;

  static FUNCTION countHits(owner VARCHAR2, index_name VARCHAR2, cmpval VARCHAR2) RETURN NUMBER is
    PREFIX     VARCHAR2(255)   := OWNER || '.' || INDEX_NAME;
    OBJ        JSON_OBJECT_T;
    REQ        UTL_HTTP.REQ;
    POST       CLOB;
    q          VARCHAR2(32767) := utl_url.escape('q=(solridx:'||prefix||') AND ('||CMPVAL||')',false,'UTF8');
    LOG_LEVEL  VARCHAR2(32)    := NVL(GETPARAMETER(PREFIX,NULL,'LogLevel'),'WARNING');
  BEGIN
    IF (LOG_LEVEL = 'INFO') THEN
          sys.dbms_system.ksdwrt(1,'CountHits : http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/select/?fl=rowid&wt=json&omitHeader=true&ident=on&rows=0&'||Q);
    END IF;
    REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/select/?fl=rowid&wt=json&omitHeader=true&ident=on&rows=0&'||Q,'GET',POST);
    OBJ := PushConnectorAdm.REQ_2_JSON_OBJECT(REQ);
    OBJ := OBJ.get_Object('response'); -- response
    return OBJ.get_Number('numFound'); -- numFound
  end countHits;

  STATIC FUNCTION countHits(index_name VARCHAR2, cmpval VARCHAR2) RETURN NUMBER is
    index_schema VARCHAR2(30);
    idx_name VARCHAR2(30) := index_name;
    hits     NUMBER := 0;
    is_part varchar2(3);
  BEGIN
    -- dbms_parallel do some overhead directly sum sequencially
    SELECT OWNER,PARTITIONED INTO INDEX_SCHEMA,IS_PART FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME;
    IF (IS_PART = 'YES') THEN
      FOR P IN (SELECT PARTITION_NAME FROM ALL_IND_PARTITIONS  WHERE INDEX_OWNER=INDEX_SCHEMA AND INDEX_NAME=IDX_NAME) LOOP
         hits := hits + countHits(index_schema,index_name|| '$' ||p.partition_name,cmpval);
      end loop;
    ELSE
      hits := countHits(index_schema,index_name,cmpval);
    end if;
    return hits;
    exception when no_data_found then
      RAISE_APPLICATION_ERROR
      (-20101, 'Index not found: '||idx_name);
    when too_many_rows then
      INDEX_SCHEMA := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
      SELECT PARTITIONED INTO IS_PART FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME and OWNER=INDEX_SCHEMA;
      IF (IS_PART = 'YES') THEN
        FOR P IN (SELECT PARTITION_NAME FROM ALL_IND_PARTITIONS  WHERE INDEX_OWNER=INDEX_SCHEMA AND INDEX_NAME=IDX_NAME) LOOP
           hits := hits + countHits(index_schema,index_name|| '$' ||p.partition_name,cmpval);
        END LOOP;
      ELSE
        HITS := COUNTHITS(INDEX_SCHEMA,INDEX_NAME,CMPVAL);
      END IF;
      return hits;
  END COUNTHITS;

  STATIC FUNCTION facet(index_name VARCHAR2,
                        Q       VARCHAR2, /* default *:* */
                        F       VARCHAR2 /* any facet Faceting Parameters encoded using URL sintax including the prefix "facet." */) RETURN f_info is
    index_schema VARCHAR2(30);
    idx_name     VARCHAR2(30) := index_name;
    v_f          f_info;
    is_part      varchar2(3);
  BEGIN
    -- dbms_parallel do some overhead directly sum sequencially
    SELECT OWNER,PARTITIONED INTO INDEX_SCHEMA,IS_PART FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME;
    IF (IS_PART = 'YES') THEN
      FOR P IN (SELECT PARTITION_NAME FROM ALL_IND_PARTITIONS  WHERE INDEX_OWNER=INDEX_SCHEMA AND INDEX_NAME=IDX_NAME) LOOP
         -- TODO: merge all facet information from each partition
         v_f := f_info(JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T());
      end loop;
    ELSE
      v_f := facet(index_schema,index_name,q,f);
    end if;
    return v_f;
    exception when no_data_found then
      RAISE_APPLICATION_ERROR
      (-20101, 'Index not found: '||idx_name);
    when too_many_rows then
      INDEX_SCHEMA := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
      SELECT PARTITIONED INTO IS_PART FROM ALL_INDEXES WHERE INDEX_NAME=IDX_NAME and OWNER=INDEX_SCHEMA;
      IF (IS_PART = 'YES') THEN
        FOR P IN (SELECT PARTITION_NAME FROM ALL_IND_PARTITIONS  WHERE INDEX_OWNER=INDEX_SCHEMA AND INDEX_NAME=IDX_NAME) LOOP
          -- TODO: merge all facet information from each partition
          v_f := f_info(JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T(),JSON_OBJECT_T());
        END LOOP;
      ELSE
        v_f := facet(index_schema,index_name,q,f);
      END IF;
      return v_f;
  END facet;

  STATIC FUNCTION facet(owner VARCHAR2, index_name VARCHAR2,
                        Q       VARCHAR2, /* default *:* */
                        F       VARCHAR2 /* any facet Faceting Parameters encoded using URL sintax including the prefix "facet." */) RETURN f_info is
      OBJ        JSON_OBJECT_T;
      PREFIX     VARCHAR2(255)   := OWNER||'.'||INDEX_NAME;
      V_F        F_INFO          := F_INFO(NULL,NULL,NULL,NULL,NULL,NULL);
      REQ        UTL_HTTP.REQ;
      QRY        VARCHAR2(32767) := 'q=solridx:'||PREFIX;
      LOG_LEVEL  VARCHAR2(32)    := NVL(GETPARAMETER(PREFIX,NULL,'LogLevel'),'WARNING');
     BEGIN
       IF (Q IS NOT NULL AND Q <> '*:*') THEN
         QRY := QRY||'+AND+('||UTL_URL.ESCAPE(q,false,'UTF8')||')';
       end if;
       if (f is not null) then
         QRY := QRY||'&'||f;
       end if;
       IF (LOG_LEVEL = 'INFO') THEN
          sys.dbms_system.ksdwrt(1,'Facet : http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/select/?wt=json&indent=on&facet=true&rows=0&'||QRY);
       END IF;
       REQ := PushConnectorAdm.CREATEREQUEST('http://'||
                                              REPLACE(NVL(GETPARAMETER(PREFIX,NULL,'Searcher'),'localhost@8983'),'@',':')||'/'||
                                              NVL(GETPARAMETER(PREFIX,NULL,'SolrBase'),'solr')||
                                              '/select/?wt=json&indent=on&facet=true&rows=0&'||QRY,'GET',OBJ);
       -- DBMS_OUTPUT.PUT_LINE('REQ complete : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
       OBJ := PUSHCONNECTORADM.REQ_2_JSON_OBJECT(REQ);
       -- DBMS_OUTPUT.PUT_LINE('OBJ parsed : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
       OBJ := TREAT(OBJ.GET('facet_counts') AS JSON_OBJECT_T); -- facet_counts
       --DBMS_OUTPUT.PUT_LINE('OBJ RETURNED : '||OBJ.to_string);
       V_F.QUERIES := TREAT(OBJ.GET('facet_queries') AS JSON_OBJECT_T);
       --DBMS_OUTPUT.PUT_LINE('QUERIES : '||V_F.QUERIES.to_string);
       V_F.FIELDS := TREAT(OBJ.GET('facet_fields') AS JSON_OBJECT_T);
       --DBMS_OUTPUT.PUT_LINE('FIELDS : '||V_F.FIELDS.to_string);
       V_F.INTERVALS := TREAT(OBJ.GET('facet_intervals') AS JSON_OBJECT_T);
       --DBMS_OUTPUT.PUT_LINE('INTERVALS : '||V_F.INTERVALS.to_string);
       V_F.RANGES := TREAT(OBJ.GET('facet_ranges') AS JSON_OBJECT_T);
       --DBMS_OUTPUT.PUT_LINE('RANGES : '||V_F.RANGES.to_string);
       V_F.HMAPS := TREAT(OBJ.GET('facet_heatmaps') AS JSON_OBJECT_T);
       --DBMS_OUTPUT.PUT_LINE('HMAPS : '||V_F.HMAPS.to_string);
       V_F.PIVOTS := TREAT(OBJ.GET('facet_pivot') AS JSON_OBJECT_T);
       --DBMS_OUTPUT.PUT_LINE('HMAPS : '||V_F.PIVOTS.to_string);
       -- DBMS_OUTPUT.PUT_LINE('facet completed : '||(DBMS_UTILITY.GET_TIME-START_TIME));START_TIME := DBMS_UTILITY.GET_TIME;
       RETURN v_f;
  END facet;
end;
/
show errors

exit
