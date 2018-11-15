-- Drops
DECLARE
  TYPE obj_arr IS TABLE OF VARCHAR2(300);
  DRP_STMT VARCHAR2(4000) := 'drop ';
  obj_list obj_arr := obj_arr('public synonym json_dyn');
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

create or replace package json_dyn authid current_user as

  /* output list with objects */
  procedure streamList(clob_o IN OUT NOCOPY CLOB, stmt varchar2, bindvar json_object_t default null);

  /* usage example:
   * declare
   *   res json_list;
   * begin
   *   res := json_dyn.executeList(
   *            'select :bindme as one, :lala as two from dual where dummy in :arraybind',
   *            json_object_t('{bindme:"4", lala:123, arraybind:[1,2,3,"X"]}')
   *          );
   *   res.print;
   * end;
   */

end json_dyn;
/
show errors

-- GRANTS
grant execute on json_dyn to public
/
create or replace public synonym json_dyn for PC.json_dyn
/

create or replace package body json_dyn as

  procedure bind_json(l_cur number, bindvar json_object_t) as
    keylist JSON_KEY_LIST := bindvar.get_keys;
  begin
    for i in 1 .. keylist.count loop
      if(bindvar.get_Type(keylist(i)) = 'SCALAR') then
        dbms_sql.bind_variable(l_cur, ':'||keylist(i), bindvar.get(i).to_string);
      elsif(bindvar.get_Type(keylist(i)) = 'ARRAY') then
        declare
          v_bind dbms_sql.varchar2_table;
          v_arr  JSON_ARRAY_T := bindvar.get_Array(keylist(i));
        begin
          for j in 0..v_arr.get_size() - 1 loop
            v_bind(j) := TREAT(v_arr.get(j) AS json_object_t).to_string;
          end loop;
          dbms_sql.bind_array(l_cur, ':'||keylist(i), v_bind);
        end;
      else
        dbms_sql.bind_variable(l_cur, ':'||keylist(i), bindvar.get(i).to_string);
      end if;
    end loop;
  end bind_json;

  /* output list with objects */
  procedure streamList(clob_o IN OUT NOCOPY CLOB, stmt varchar2, bindvar json_object_t) as
    l_cur number;
    l_dtbl dbms_sql.desc_tab;
    l_cnt number;
    l_status number;
    read_clob clob;
    --CHARBUFF     VARCHAR2(32767);
    amount number := dbms_lob.getlength(clob_o);
  begin
    if(amount > 0) then dbms_lob.trim(clob_o, 0); dbms_lob.erase(clob_o, amount); end if;
    l_cur := dbms_sql.open_cursor;
    dbms_sql.parse(l_cur, stmt, dbms_sql.native);
    if(bindvar is not null) then bind_json(l_cur, bindvar); end if;
    dbms_sql.describe_columns(l_cur, l_cnt, l_dtbl);
    if (l_cnt <> 1) then
       RAISE_APPLICATION_ERROR
       (-20101, 'json_dyn.streamList expected one column result for query: '||stmt);
    end if;
    if (l_dtbl(1).col_type <> 112) then
       RAISE_APPLICATION_ERROR
       (-20101, 'json_dyn.streamList column type is not CLOB: '||stmt);
    else
        dbms_sql.define_column(l_cur,1,read_clob);
    end if;
    l_status := dbms_sql.execute(l_cur);

    dbms_lob.writeappend(clob_o,1,'['); --init
    --loop through rows
    while ( dbms_sql.fetch_rows(l_cur) > 0 ) loop
      read_clob := '';
      dbms_sql.column_value(l_cur,1,read_clob);
      dbms_lob.writeappend(clob_o,dbms_lob.getlength(read_clob),read_clob);
      dbms_lob.writeappend(clob_o,1,',');
    end loop;
    dbms_sql.close_cursor(l_cur);
    dbms_lob.trim(clob_o,dbms_lob.getlength(clob_o)-1);
    dbms_lob.writeappend(clob_o,1,']'); --end
    --charbuff := dbms_lob.SUBSTR (clob_o,32767,1);
    --sys.dbms_system.ksdwrt(1,'----- charbuff begin -----');
    --sys.dbms_system.ksdwrt(1,charbuff);
    --sys.dbms_system.ksdwrt(1,'----- charbuff end   -----');
  end streamList;
end json_dyn;
/
show errors

exit
