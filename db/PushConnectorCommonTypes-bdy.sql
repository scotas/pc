
---------------------------------------------------------------------
--    LUCENE Index Method  common types bdy                        --
---------------------------------------------------------------------
create or replace PACKAGE BODY solrresultset IS

    PROCEDURE parse (
        p_docs    json_array_t,
        s_score   BOOLEAN DEFAULT true,
        n_score   NUMBER DEFAULT 1,
        p_hl      json_object_t DEFAULT NULL,
        p_ml      json_object_t DEFAULT NULL
    ) IS
        obj      json_object_t;
        keys     json_key_list;
        li_arr   json_array_t;
        m_list   sys.odciridlist;
    BEGIN
        --dbms_output.put_line('parse: ' || p_docs.to_string);
        IF ( p_hl IS NOT NULL ) THEN
            highlighting := highlighting_tbl();
            keys := p_hl.get_keys;
            --dbms_output.put_line('keys.count: ' || keys.count);
            FOR i IN 1..keys.count LOOP
                --dbms_output.put_line('keys(('
                --                     || i
                --                     || '):'
                --                    || keys(i)
                --                     || '  value:'
                --                     || p_hl.get(keys(i)).to_string);

                highlighting(keys(i)) := p_hl.get(keys(i)).to_string;

            END LOOP;

        END IF;

        IF ( p_ml IS NOT NULL ) THEN
            mlt := morelikethis_tbl();
            keys := p_ml.get_keys;
            --dbms_output.put_line('keys.count: ' || keys.count);
            FOR i IN 1..keys.count LOOP
                obj := TREAT(p_ml.get(keys(i)) AS json_object_t);
                --dbms_output.put_line(keys(i));
                m_list := sys.odciridlist();
                li_arr := obj.get_array('docs');
                FOR j IN 0..li_arr.get_size() - 1 LOOP
                    m_list.extend;
                    m_list(j + 1) := TREAT(li_arr.get(j) AS json_object_t).get_string('rowid');
                    --dbms_output.put_line('   ' || m_list(j + 1));
                END LOOP;

                mlt(keys(i)) := m_list;
            END LOOP;

        END IF;

        j_list := sys.odciridlist();
        IF ( s_score ) THEN
            scores := score_tbl();
        END IF;
        FOR i IN 0..p_docs.get_size() - 1 LOOP
            obj := json_object_t(p_docs.get(i));
            j_list.extend;
            j_list(i + 1) := obj.get_string('rowid');
            IF ( s_score ) THEN
                scores(j_list(i + 1)) := obj.get_string('score') * n_score;
                --dbms_output.put_line(j_list(i + 1) ||'(' || (i + 1) || ')' || scores(j_list(i + 1)));
            END IF;

        END LOOP;

    END parse;

    FUNCTION gethlt (
        rid IN   VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN highlighting(rid);
    END gethlt;

    FUNCTION getmlt (
        rid IN   VARCHAR2
    ) RETURN sys.odciridlist IS
    BEGIN
        RETURN mlt(rid);
    END getmlt;

    FUNCTION getscore (
        rid IN   VARCHAR2
    ) RETURN NUMBER IS
    BEGIN
        RETURN scores(rid);
    END getscore;

END solrresultset;

/
show errors

CREATE OR REPLACE TYPE BODY ridlist_tbl_stats_ot AS
     STATIC FUNCTION ODCIGetInterfaces (
                     p_interfaces OUT SYS.ODCIObjectList
                     ) RETURN NUMBER IS
     BEGIN
        p_interfaces := SYS.ODCIObjectList(
                           SYS.ODCIObject ('SYS', 'ODCISTATS2')
                           );
        RETURN ODCIConst.success;
     END ODCIGetInterfaces;

     STATIC FUNCTION ODCIStatsTableFunction (
                     p_function IN  SYS.ODCIFuncInfo,
                     p_stats    OUT SYS.ODCITabFuncStats,
                     p_args     IN  SYS.ODCIArgDescList,
                     ridlist    IN sys.odciridlist
                     ) RETURN NUMBER IS
     BEGIN
        p_stats := SYS.ODCITabFuncStats(ridlist.last);
        RETURN ODCIConst.success;
     END ODCIStatsTableFunction;
END;
/
show errors

ASSOCIATE STATISTICS WITH FUNCTIONS ridlist_tbl USING ridlist_tbl_stats_ot
/

exit
