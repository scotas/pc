set long 10000 lines 140 pages 50 timing on echo on
set serveroutput on size 1000000 

create table test_source_big as (
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=0 and ntop_pos<=5000
);



CREATE INDEX SOURCE_BIG_PIDX ON TEST_SOURCE_BIG(TEXT)
INDEXTYPE IS PC.SOLR
parameters('{LogLevel:"INFO",
             Updater:"solr@8983",
             Searcher:"solr@8983",
             SolrBase:"solr/source_big_pidx",
             SyncMode:"OnLine",
             BatchCount:5000,
             CommitOnSync:true,
             LockMasterTable:false,
             IncludeMasterColumn:false,
             DefaultColumn:"text",
             HighlightColumn:"title",
             ExtraCols:"''text'' value text,''title'' value substr(text,1,256),''line_i'' value line,''type_s'' value type"}');


alter index SOURCE_BIG_PIDX parameters('{CommitOnSync:true}');

begin
  SolrPushConnector.sync('SOURCE_BIG_PIDX');
end;
/

begin
  SolrPushConnector.optimize('SOURCE_BIG_PIDX');
end;
/


create index source_big_idx on test_source_big(text)
indextype is ctxsys.context
filter by type,line
order by type,line
parameters('SYNC (MANUAL) TRANSACTIONAL');

create index source_big_idx on test_source_big(text) 
indextype is ctxsys.context; 

insert into test_source_big
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=5000 and ntop_pos<20000;
begin
   SolrPushConnector.sync('SOURCE_BIG_PIDX');
   commit;
end;
/

select sc,TEXT from (select rownum as ntop_pos,q.* from
(select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc,text from test_source_big where scontains(text,'function',1)>0 order by sscore(1) asc) q)
where ntop_pos>=0 and ntop_pos<10;

select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc,text from test_source_big where scontains(text,'rownum:[1 TO 10] AND function',1)>0 order by sscore(1) asc;

select sscore(1),shighlight(1) from test_source_big where scontains(text,'"procedure java"~10',1)>0 order by sscore(1) desc;
select sscore(1),shighlight(1) from test_source_big where scontains(text,'"procedure java"~10',1)>0 order by sscore(1) asc;
select /*+ DOMAIN_INDEX_SORT */ sscore(1) from test_source_big where scontains(text,'(logLevel OR prefix) AND "LANGUAGE JAVA"',1)>0 order by sscore(1) asc;
select /*+ DOMAIN_INDEX_SORT */ sscore(1) from test_source_big where scontains(text,'(logLevel OR prefix) AND "LANGUAGE JAVA"',1)>0;

declare
  obj JSON_OBJECT_T;
  li_arr   json_array_t;
BEGIN
  OBJ := SolrPushConnector.facet('SOURCE_BIG_PIDX',null,'facet.field=type_s').fields;
  li_arr := obj.get_array('type_s');
    dbms_output.put_line(li_arr.to_string);
END;

insert into test_source_big
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=20000 and ntop_pos<40000;


insert into test_source_big
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=20000 and ntop_pos<40000;



select sc,TEXT from (select rownum as ntop_pos,q.* from
(select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc, text 
from test_source_big where scontains(text,'function',1)>0 order by sscore(1) asc) q)
where ntop_pos>=100 and ntop_pos<110;

select sc,TEXT from (select rownum as ntop_pos,q.* from
(select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc, text 
from test_source_big where scontains(text,'function',1)>0 order by sscore(1) asc) q)
where ntop_pos>=100 and ntop_pos<110;

select sc,TEXT from (select rownum as ntop_pos,q.* from
(select /*+ DOMAIN_INDEX_SORT */ score(1) sc, text 
from test_source_big where contains(text,'function',1)>0 order by score(1) asc) q)
where ntop_pos>=100 and ntop_pos<110;


select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc, shighlight(1) 
from test_source_big where scontains(text,'rownum:[100 TO 109] AND function',1)>0 order by sscore(1) asc;


select count(line) from test_source_big
  where scontains(text,'function')>0 and line>=2600;


select count(line) from test_source_big
  where scontains(text,'function AND line_i:[2600 TO *]')>0;


select SolrPushConnector.countHits('SOURCE_BIG_PIDX','function AND line_i:[2600 TO *]') from dual;






select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc, text 
from test_source_big where scontains(text,'rownum:[2000 TO 2010] AND type',1)>0 order by sscore(1) asc;


declare 
  hits NUMBER;
  fromRow NUMBER;
  toRow NUMBER;
  sc    NUMBER;
  text  VARCHAR2(4000);
  CURSOR c1 (fromRow NUMBER, toRow NUMBER) IS select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc,text
             from test_source_big where scontains(text,'rownum:['||fromRow||' TO '||toRow||'] AND (number OR varchar2 OR date) AND line_i:[1 TO 100]',1)>0 
             order by sscore(1) ASC;
begin
  hits := SolrPushConnector.countHits('SOURCE_BIG_PIDX','(number OR varchar2 OR date) AND line_i:[1 TO 100]');
  fromRow := round(dbms_random.value(1,hits*0.75));
  toRow := fromRow+10;
  dbms_output.put_line('Count Hits: '||hits);
  dbms_output.put_line('Score list from rownum: '||fromRow||' to: '||toRow);
  for j in 1..10 loop
    OPEN c1(fromRow+(j*10),toRow+((j+1)*10)); 
    LOOP
       
       FETCH c1 INTO sc, text;
       DBMS_OUTPUT.PUT_LINE('SC: '||SC||' TEXT: '||TEXT);
       EXIT WHEN c1%NOTFOUND;
       null;
    END LOOP;
    CLOSE c1;
  end loop;
end;
/

declare 
  hits NUMBER;
  fromRow NUMBER;
  toRow NUMBER;
  sc    NUMBER;
  text  VARCHAR2(4000);
  CURSOR c1 (fromRow NUMBER, toRow NUMBER) IS select sc,TEXT from (select rownum as ntop_pos,q.* from
               (select /*+ DOMAIN_INDEX_SORT DOMAIN_INDEX_FILTER(test_source_big source_big_idx) */ score(1) sc, text 
                from test_source_big where contains(text,'function OR procedure OR package',1)>0 and line between 1 and 100 order by score(1) asc) q)
                where ntop_pos>=fromRow and ntop_pos<=toRow;
begin
  hits := ctx_query.count_hits(index_name => 'source_big_idx', text_query => 'function OR procedure OR package', exact => TRUE);
  fromRow := round(dbms_random.value(1,hits*0.75));
  toRow := fromRow+10;
  dbms_output.put_line('Count Hits: '||hits);
  dbms_output.put_line('Score list from rownum: '||fromRow||' to: '||toRow);
  for j in 1..10 loop
    OPEN c1(fromRow+(j*10),toRow+((j+1)*10)); 
    LOOP
       
       FETCH c1 INTO sc, text;
       DBMS_OUTPUT.PUT_LINE('SC: '||SC||' TEXT: '||TEXT);
       EXIT WHEN c1%NOTFOUND;
       null;
    END LOOP;
    CLOSE c1;
  end loop;
end;
/


select text,line from
(select rownum as ntop_pos,q.* from
  (select /*+ DOMAIN_INDEX_SORT DOMAIN_INDEX_FILTER(test_source_big source_big_idx) */ text, line from test_source_big
   where contains(text,'function OR procedure OR package',1)>0 and line between 0 and 3000 order by line DESC) q)
 where ntop_pos>=1 and ntop_pos<=10;
