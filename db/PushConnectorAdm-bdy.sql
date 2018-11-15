-- prevent escape processing
set define off

----------------------------------------------------------------------------------
--    Solr Push Connector Domain Index Admin Methods                            --
----------------------------------------------------------------------------------
create or replace package body PushConnectorAdm as
  debug_enable boolean := false;
  
  PROCEDURE AQ_ERROR(ridlist sys.ODCIRidList, operation VARCHAR2, prefix VARCHAR2) IS
    enqueue_options     DBMS_AQ.enqueue_options_t;
    message_properties  DBMS_AQ.message_properties_t;
    message_handle      RAW(16);
    message             PC.pc_error_typ;
  begin
    message := PC.pc_error_typ(PC.pc_msg_typ(ridlist,operation),prefix,substr(DBMS_UTILITY.format_error_stack,1,4000));
    enqueue_options.visibility         := dbms_aq.immediate;
    dbms_aq.enqueue(queue_name         => 'PC.ERRORS$Q',
                    enqueue_options    => enqueue_options,
                    message_properties => message_properties,
                    payload            => message,
                    msgid              => message_handle);
  end AQ_ERROR;
  
  PROCEDURE CREATEQUEUE(PREFIX VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
      EXECUTE IMMEDIATE
'begin DBMS_AQADM.CREATE_QUEUE_TABLE(queue_table        => :1,
                                     queue_payload_type => ''PC.pc_msg_typ'',
                                     sort_list          => ''ENQ_TIME'',
                                     message_grouping   => DBMS_AQADM.NONE,
                                     compatible         => ''10.2'',
                                     multiple_consumers => FALSE); end;' USING PREFIX||'$QT';
      EXECUTE IMMEDIATE
'begin DBMS_AQADM.CREATE_QUEUE(queue_name         => :1,
                               queue_table        => :2,
                               queue_type         => DBMS_AQADM.NORMAL_QUEUE); end;' USING PREFIX||'$Q',PREFIX||'$QT';
      EXECUTE IMMEDIATE
'begin DBMS_AQADM.START_QUEUE(queue_name         => :1); end;' USING PREFIX||'$Q';
    exception when others then
          sys.dbms_system.ksdwrt(1,'createQueue Exception');
          sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
  end createQueue;

  PROCEDURE DROPQUEUE(PREFIX VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
      begin
         EXECUTE IMMEDIATE
            'begin DBMS_AQADM.STOP_QUEUE (queue_name         => :1); end;' USING PREFIX||'$Q';
      exception when others then
          sys.dbms_system.ksdwrt(1,'dropQueue Exception');
          sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
      end;
      begin
-- drop the table with force will automatically drop the queue;
         EXECUTE IMMEDIATE
            'begin DBMS_AQADM.DROP_QUEUE_TABLE (queue_table  => :1, force => true); end;' USING PREFIX||'$QT';
      exception when others then
          sys.dbms_system.ksdwrt(1,'dropQueue Exception');
          sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
      end;
  end dropQueue;

  procedure purgueQueue(prefix VARCHAR2) is
    po dbms_aqadm.aq$_purge_options_t;
  begin
      EXECUTE IMMEDIATE
'declare po dbms_aqadm.aq$_purge_options_t; begin po.block := FALSE; DBMS_AQADM.PURGE_QUEUE_TABLE (queue_table  => :1, purge_condition => NULL, purge_options   => po); end;' USING PREFIX||'$QT';
  exception when others then
          sys.dbms_system.ksdwrt(1,'purgueQueue Exception');
          sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
  end purgueQueue;

   FUNCTION PARSE_RESPONSE(resp  UTL_HTTP.RESP)
            RETURN UTL_HTTP.RESP
   IS
   BEGIN
      -- Merken Respond
      g_last_status_code   := resp.status_code;
      g_last_reason_phrase := resp.reason_phrase;
      --
      -- Debugging:
      -- dbms_output.put_line('resp.status_code' || resp.status_code);
      -- dbms_output.put_line('resp.reason_phrase' || resp.reason_phrase);
      RETURN resp;
   END PARSE_RESPONSE;

   PROCEDURE REQ_2_CLOB(req     IN OUT UTL_HTTP.REQ
                      ,v_clob  IN OUT CLOB)
   IS
      resp       UTL_HTTP.RESP;
      isError    boolean := false;
      READTEXT   VARCHAR2(32767);
      --name       VARCHAR2(256);
      --value      VARCHAR2(256);
   BEGIN
      resp := PARSE_RESPONSE(UTL_HTTP.GET_RESPONSE(req));
      --
      -- for debugging
      --FOR i IN 1..UTL_HTTP.GET_HEADER_COUNT(resp) LOOP
      -- UTL_HTTP.GET_HEADER(resp, i, name, value);
      -- DBMS_OUTPUT.PUT_LINE(name || ': ' || value);
      --END LOOP;
      BEGIN
        -- Get result
        v_clob := NULL;
        LOOP
          UTL_HTTP.READ_TEXT(resp, readText);
          if readText IS NOT NULL THEN
            -- jsonText := NVL(jsonText,'') || value;
            IF v_clob IS NULL THEN
              v_clob := readText;
            ELSE
              dbms_lob.append(v_clob, readText);
            END IF;
          END IF;
        END LOOP;
        UTL_HTTP.END_RESPONSE(resp);
          isError := true;
      EXCEPTION
        WHEN UTL_HTTP.END_OF_BODY THEN
          UTL_HTTP.END_RESPONSE(resp);
          isError := false;
        WHEN OTHERS THEN
          sys.dbms_system.ksdwrt(1,DBMS_UTILITY.format_error_stack);
          isError := true;
      END;
   END REQ_2_CLOB;

   FUNCTION  REQ_2_JSON_OBJECT(req IN OUT UTL_HTTP.REQ) RETURN JSON_OBJECT_T
   IS
      v_clob     CLOB;
      je         JSON_ELEMENT_T;
      jo         JSON_OBJECT_T;
   BEGIN
      v_clob := NULL;
      REQ_2_CLOB(req, v_clob);

      IF V_CLOB IS NOT NULL THEN
        --DBMS_OUTPUT.PUT_LINE('------------- result start -------------' || v_clob);
        --DBMS_OUTPUT.PUT_LINE('result:' || v_clob);
        --DBMS_OUTPUT.PUT_LINE('------------- result end -------------' || v_clob);
        je := JSON_ELEMENT_T.parse(v_clob);
        IF (je.is_Object) THEN
            jo := treat(je AS JSON_OBJECT_T);
            IF (jo.has('error')) then
                jo := treat(jo.get('error') AS JSON_OBJECT_T);
                raise_application_error(-20101, 'Solr backend error: ' || jo.get_String('msg'));
            ELSE
                RETURN jo;
            END IF;
        END IF;
        RETURN NULL;
      END IF;
      RETURN NULL;
   END REQ_2_JSON_OBJECT;
   
  FUNCTION CREATEREQUEST(URL     VARCHAR2  DEFAULT NULL,
                         REQUEST VARCHAR2  DEFAULT NULL,
                         JSONOBJ IN OUT NOCOPY JSON_OBJECT_T )
            RETURN UTL_HTTP.REQ IS
    REQ           UTL_HTTP.REQ;
    V_CLOB        CLOB;
  BEGIN
    V_CLOB := ' ';
    IF JSONOBJ IS NOT NULL THEN
       V_CLOB := JSONOBJ.to_Clob();
    END IF;
    return CREATEREQUEST(URL,REQUEST,V_CLOB);
  END;

  FUNCTION CREATEREQUEST(URL     VARCHAR2  DEFAULT NULL,
                         REQUEST VARCHAR2  DEFAULT NULL,
                         HTTP_CONTENT IN OUT NOCOPY CLOB)
            RETURN UTL_HTTP.REQ IS
    REQ           UTL_HTTP.REQ;
    V_OLD_TIMEOUT PLS_INTEGER;
    V_URL         VARCHAR2(2048);
    -- logging info
    l_rindex          PLS_INTEGER;
    l_slno            PLS_INTEGER;
    l_totalwork       NUMBER := 1;
    l_sofar           NUMBER := 1;
    l_obj             PLS_INTEGER;
    l_opname          VARCHAR2(64);
    length_bytes      NUMBER;
  BEGIN
      IF URL IS NULL THEN
         v_url := 'http://localhost:8983/solr/select/?wt=json&ident=on';
      ELSE
         V_URL := URL;
      END IF;
      -- Save the old timeout
      UTL_HTTP.GET_TRANSFER_TIMEOUT(V_OLD_TIMEOUT);
      IF G_TIMEOUT > 0 THEN
         UTL_HTTP.SET_TRANSFER_TIMEOUT(g_timeout);   -- timeout for the future requests in this session
      ELSE
         UTL_HTTP.SET_TRANSFER_TIMEOUT(60);   -- Default timeout
      END IF;
      --
      req := UTL_HTTP.BEGIN_REQUEST(v_url, NVL(request,'GET'), 'HTTP/1.0');
      UTL_HTTP.SET_HEADER(req, 'User-Agent', 'Mozilla/4.0');
      --DBMS_OUTPUT.PUT_line('GET: ' || v_url);
      --
      -- Send JSon-Object
      -- First VARCHAR2
      IF HTTP_CONTENT IS NOT NULL THEN
        DECLARE
          -- v_output   VARCHAR2(32767);
          written      NUMBER := 0;
          writtensize  NUMBER := 2048;
          CHARBUFF     VARCHAR2(4096); -- prepared for multibytes chars
        BEGIN
          UTL_HTTP.SET_BODY_CHARSET(REQ,'UTF8');
          -- UTF8 chars length are not the same as bytes, use Transfer-Encoding: chunked
          --UTL_HTTP.SET_HEADER(REQ, 'Content-Length', TO_CHAR(dbms_lob.getlength(HTTP_CONTENT)));
          UTL_HTTP.SET_HEADER(REQ, 'Transfer-Encoding', 'chunked');
          UTL_HTTP.SET_HEADER(REQ, 'Content-Type', 'application/json; charset=utf-8');
          --sys.dbms_system.ksdwrt(1,'REQ start');
          WHILE (written + writtensize) < DBMS_LOB.GETLENGTH(HTTP_CONTENT) LOOP
            charbuff := DBMS_LOB.SUBSTR (HTTP_CONTENT
                                        ,writtensize
                                        ,written + 1);
            WRITTEN := WRITTEN + WRITTENSIZE;
            UTL_HTTP.WRITE_TEXT(REQ,  CHARBUFF);
            --sys.dbms_system.ksdwrt(1,CHARBUFF);
          END LOOP;
          IF written < DBMS_LOB.GETLENGTH(HTTP_CONTENT) THEN
            charbuff := DBMS_LOB.SUBSTR (HTTP_CONTENT
                                        ,DBMS_LOB.GETLENGTH(HTTP_CONTENT) - written
                                        ,WRITTEN + 1);
            UTL_HTTP.WRITE_TEXT(REQ, CHARBUFF);
            --sys.dbms_system.ksdwrt(1,CHARBUFF);
          END IF;
          --sys.dbms_system.ksdwrt(1,'');
          --sys.dbms_system.ksdwrt(1,'REQ end');
        END;
      END IF;
      --
      -- Set the old Timeout
      UTL_HTTP.SET_TRANSFER_TIMEOUT(v_old_timeout);   -- timeout for all future requests in this session
      if (debug_enable) then
        l_rindex    := DBMS_APPLICATION_INFO.set_session_longops_nohint;
        l_opname := substr(v_url,instr(v_url,':',7,1)+1,64);
        l_opname := substr(l_opname,instr(l_opname,'/')+1,64);
        DBMS_APPLICATION_INFO.set_session_longops(
          rindex      => l_rindex, 
          slno        => l_slno,
          op_name     => l_opname, 
          target      => l_obj, 
          context     => 0, 
          sofar       => l_sofar, 
          totalwork   => l_totalwork, 
          target_desc => NVL(request,'GET'), 
          units       => 'http_request');
      end if;
      RETURN REQ;
    return REQ;
  END createRequest;
end;
/
show errors

exit
