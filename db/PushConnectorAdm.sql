------------------------------------------------------------------------------
--    Push Connectors Domain Index Admin Methods                            --
------------------------------------------------------------------------------
-- Drops
DECLARE
  stmt VARCHAR2(4000) := 'drop public synonym PushConnectorAdm';
BEGIN
  execute immediate stmt;
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
/

-- drop package PushConnectorAdm;

create or replace package PushConnectorAdm authid definer as
  -- last status code
  G_LAST_STATUS_CODE VARCHAR2(32) := NULL;
  -- last reason-phrase
  G_LAST_REASON_PHRASE VARCHAR2(32) := NULL;
  -- last error
  G_LAST_ERROR VARCHAR2(32767) := NULL;
  -- reason from the last error
  G_LAST_ERROR_REASON VARCHAR2(32767) := NULL;
  -- Timeout for the (future) requests to the Solr (See UTL_HTTP);
  G_TIMEOUT   NUMBER        := 0;

  PROCEDURE CREATEQUEUE(PREFIX VARCHAR2);
  PROCEDURE DROPQUEUE(PREFIX VARCHAR2);
  PROCEDURE PURGUEQUEUE(PREFIX VARCHAR2);
  FUNCTION  PARSE_RESPONSE(resp  UTL_HTTP.RESP) RETURN UTL_HTTP.RESP;
  PROCEDURE REQ_2_CLOB(REQ IN OUT UTL_HTTP.REQ,
                       V_CLOB  IN OUT NOCOPY CLOB);
  FUNCTION  REQ_2_JSON_OBJECT(req IN OUT UTL_HTTP.REQ) RETURN JSON_OBJECT_T;
  FUNCTION  CREATEREQUEST(URL         VARCHAR2  DEFAULT NULL,
                          REQUEST     VARCHAR2  DEFAULT NULL,
                          JSONOBJ     IN OUT NOCOPY JSON_OBJECT_T ) RETURN UTL_HTTP.REQ;
  FUNCTION  CREATEREQUEST(URL          VARCHAR2  DEFAULT NULL,
                          REQUEST      VARCHAR2  DEFAULT NULL,
                          HTTP_CONTENT IN OUT NOCOPY CLOB ) RETURN UTL_HTTP.REQ;
  PROCEDURE AQ_ERROR(ridlist sys.ODCIRidList, operation VARCHAR2, prefix VARCHAR2);
  PRAGMA RESTRICT_REFERENCES (PARSE_RESPONSE, wnds, rnds, trust);
  PRAGMA RESTRICT_REFERENCES (REQ_2_CLOB, wnds, rnds, trust);
  PRAGMA RESTRICT_REFERENCES (REQ_2_JSON_OBJECT, wnds, rnds, trust);
  PRAGMA RESTRICT_REFERENCES (CREATEREQUEST, wnds, rnds, trust);
end;
/
show errors

-- GRANTS
grant execute on PushConnectorAdm to public
/
create public synonym PushConnectorAdm for PC.PushConnectorAdm
/
exit
