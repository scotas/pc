set long 10000 lines 140 pages 50 timing on echo on
set serveroutput on size 1000000 

-- drop table test_source_big;
-- Demo indexing a big table (594k rows)
create table test_source_big as (
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=0 and ntop_pos<=5000
);

/*
-- Minimun change at Solr schema in order to PC works
$ bin/solr create_core -c source_big_pidx

$ curl -X POST -H 'Content-type:application/json' --data-binary '{
  "add-field":{
     "name":"rowid",
     "type":"string",
     "indexed":true,
     "stored":true,
     "required":true,
     "multiValued":false
  },
  "add-field":{
     "name":"solridx",
     "type":"string",
     "indexed":true,
     "stored":true,
     "required":true,
     "multiValued":false
  }
}' http://localhost:8983/solr/source_big_pidx/schema

$ sed -i 's/<uniqueKey>id/<uniqueKey>rowid/g' /opt/solr/server/solr/source_big_pidx/conf/managed-schema
$ curl "http://localhost:8983/solr/admin/cores?action=RELOAD&core=source_big_pidx"

-- Tutorial custom
$ curl -X POST -H 'Content-type:application/json' --data-binary '{
  "add-field":{
     "name":"title",
     "type":"text_general",
     "indexed":true,
     "stored":true,
     "multiValued":true
  },
  "add-copy-field" :{
     "source":"*",
     "dest":"_text_"
  }
}' http://localhost:8983/solr/source_big_pidx/schema

$ curl -X POST -H 'Content-type:application/json' --data-binary '{
  "delete-field" : { "name":"id" }
}' http://localhost:8983/solr/source_big_pidx/schema

$ curl http://localhost:8983/solr/source_big_pidx/schema/uniquekey?wt=json
{
  "responseHeader":{
    "status":0,
    "QTime":0},
  "uniqueKey":"rowid"}

*/

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

-- LucidWorks enterprise server
-- previous enable connection on 11g/12c/18c as sys SQL> exec DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(acl => 'solr.xml', host => 'localhost', lower_port => 8888, upper_port => 8888);

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
-- Index created.
-- Elapsed: 00:01:11.72

create index source_big_idx on test_source_big(text) 
indextype is ctxsys.context; 
-- SQL> create index source_big_idx on test_source_big(text)
--   2  indextype is ctxsys.context;
-- Index created.
-- Elapsed: 00:01:22.93

insert into test_source_big
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=5000 and ntop_pos<20000;
begin
   SolrPushConnector.sync('SOURCE_BIG_PIDX');
   commit;
end;
/

-- Must return 9 rows
-- bad performance, too many rows comming from Solr
select sc,TEXT from (select rownum as ntop_pos,q.* from
(select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc,text from test_source_big where scontains(text,'function',1)>0 order by sscore(1) asc) q)
where ntop_pos>=0 and ntop_pos<10;

-- best performance, filter at index level
select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc,text from test_source_big where scontains(text,'rownum:[1 TO 10] AND function',1)>0 order by sscore(1) asc;

-- Must return 9 rows
select sscore(1),shighlight(1) from test_source_big where scontains(text,'"procedure java"~10',1)>0 order by sscore(1) desc;
select sscore(1),shighlight(1) from test_source_big where scontains(text,'"procedure java"~10',1)>0 order by sscore(1) asc;
-- Must return 22 rows
select /*+ DOMAIN_INDEX_SORT */ sscore(1) from test_source_big where scontains(text,'(logLevel OR prefix) AND "LANGUAGE JAVA"',1)>0 order by sscore(1) asc;
select /*+ DOMAIN_INDEX_SORT */ sscore(1) from test_source_big where scontains(text,'(logLevel OR prefix) AND "LANGUAGE JAVA"',1)>0;

set define off serveroutput on timing on
declare
  obj      f_info;
BEGIN
  obj := SolrPushConnector.facet('SOURCE_BIG_PIDX',null,'facet.field=type_s&facet.limit=5&facet.pivot=type_s,line_i');
  dbms_output.put_line(obj.fields.to_string);
  dbms_output.put_line(obj.pivots.to_string);
END;
/

alter index SOURCE_BIG_PIDX parameters('{CommitOnSync:false}');
alter index SOURCE_BIG_PIDX parameters('{SyncMode:"OnLine"}');

insert into test_source_big
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=20000 and ntop_pos<40000;
commit;

insert into test_source_big
select owner,name,type,line,text from (select rownum as ntop_pos,q.* from
(select * from all_source) q)
where ntop_pos>=40000 and ntop_pos<60000;
commit;

-- Test execution time: 00:00:05.82
-- bad performance do not try this
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

-- inline pagination version using lcontains "rownum:[n TO m] AND" option
select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc, shighlight(1) 
from test_source_big where scontains(text,'rownum:[100 TO 109] AND function',1)>0 order by sscore(1) asc;

-- bad performance do not try this, use domain index filter
select count(line) from test_source_big
  where scontains(text,'function')>0 and line>=2600;

-- best performance, domain index filter  
select count(line) from test_source_big
  where scontains(text,'function AND line_i:[2600 TO *]')>0;

-- even faster than previous one
select SolrPushConnector.countHits('SOURCE_BIG_PIDX','function AND line_i:[2600 TO *]') from dual;

-- Query equivalent using 11g/12c/18c Composite index filter by functionality
-- select /*+ DOMAIN_INDEX_SORT DOMAIN_INDEX_FILTER(test_source_big source_big_idx) */ count(*) from test_source_big
-- where contains(text,'varchar2')>0 and line between 2600 and 9000;

-- inline pagination version using scontains "rownum:[n TO m] AND" option
select /*+ DOMAIN_INDEX_SORT */ sscore(1) sc, text 
from test_source_big where scontains(text,'rownum:[2000 TO 2009] AND type',1)>0 order by sscore(1) asc;

-- countHits example
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
  toRow := fromRow+9;
  dbms_output.put_line('Count Hits: '||hits);
  dbms_output.put_line('Score list from rownum: '||fromRow||' to: '||toRow);
  for j in 1..10 loop
    OPEN c1(fromRow+(j*10),toRow+(j*10)); -- open the cursor before fetching
    LOOP
       -- Fetches 2 columns into variables
       FETCH c1 INTO sc, text;
       DBMS_OUTPUT.PUT_LINE('SC: '||SC||' TEXT: '||TEXT);
       EXIT WHEN c1%NOTFOUND;
       null;
    END LOOP;
    CLOSE c1;
  end loop;
end;
/

-- Oracle Context example to compare performance
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
  toRow := fromRow+9;
  dbms_output.put_line('Count Hits: '||hits);
  dbms_output.put_line('Score list from rownum: '||fromRow||' to: '||toRow);
  for j in 1..10 loop
    OPEN c1(fromRow+(j*10),toRow+(j*10)); -- open the cursor before fetching
    LOOP
       -- Fetches 2 columns into variables
       FETCH c1 INTO sc, text;
       DBMS_OUTPUT.PUT_LINE('SC: '||SC||' TEXT: '||TEXT);
       EXIT WHEN c1%NOTFOUND;
       null;
    END LOOP;
    CLOSE c1;
  end loop;
end;
/

/*
composite domain index comparison
-- 11g/12c/18c composite index syntax
-- SQL> create index source_big_idx on test_source_big(text)
--   2  indextype is ctxsys.context
--   3  filter by line
--   4  order by line;
-- Index created.
-- Elapsed: 00:00:53.82

*/
select text,line from
(select rownum as ntop_pos,q.* from
  (select /*+ DOMAIN_INDEX_SORT DOMAIN_INDEX_FILTER(test_source_big source_big_idx) */ text, line from test_source_big
   where contains(text,'function OR procedure OR package',1)>0 and line between 0 and 3000 order by line DESC) q)
 where ntop_pos>=1 and ntop_pos<=10;
