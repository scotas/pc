create table t1 (f1 number primary key, f2 varchar2(200), f3 number(4,2)) ORGANIZATION INDEX
;
insert into t1 values (1, 'ravi', 3.46);
insert into t1 values (3, 'murthy', 15.87);

CREATE INDEX IT1 ON T1(F2) INDEXTYPE IS PC.SOLR 
  parameters('{DefaultColumn:text,IncludeMasterColumn:false,ExtraCols:"F2 \"text\",F3 \"f3_tf\""}')
;
