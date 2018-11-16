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
CREATE OR REPLACE TYPE f_info wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
d
d1 b2
Nwkf/tSILbt5HFj8S59Lnpf5H68wgzLZLcusZy/pzPa8Bo3szrYdIjKFwpi5XxQrBfe0j7W/
0z6vBUFxqgHg5btCkmd0Js0xrUqypTDCFrIM7WNU6uU/h4rldJwseS6MA1/TfsYY2/21z/41
m/K62XsbmjrstuDAkW9ex94dKA/OFSH5

/
show errors
create or replace type pc_msg_typ wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
d
58 92
8p7vVqUG/qB/TBxMpTmucsm2dL0wg5n0dLhcFlpKcmLc0JYmVmm4dCulv5vAMsvMUI8Jaeeb
9QgIdMvMpjePhXAAqh8Xrk11y2mDJN0qhX/b65ooFqSLBF2K7gSRGjh+Gvpj+qamJMFvqQ==


/
show errors
create or replace type pc_error_typ wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
d
73 aa
97KZPVPgwCcVT5gbTZWFE5on0NIwg5n0dLhcFlpKrmLFl5YYliZWabh0K6W/m8Ayy8xQjwlp
uMfS0lIy9P4oaWlp57hK/rKf0Cj0dFD7lzY2vkVCYBapNXULyAMHC8j3QC33G1r/KhaFJOca
BJP/293dZ7cMt/umPnx2/A==

/
show errors
CREATE OR REPLACE TYPE rowid_tbl AS TABLE OF VARCHAR2(5072)
/
show errors
create or replace
TYPE agg_attributes wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
d
60 8d
bUC7RW3rrM1OLb2W/ZaWaPSxWbUwg5n0dLhcWlmu0K5WPj6XWcVioWIruHQrpb+bwDLL7gmm
HbIC3Q6FL7HjL+d4R3+FMWp/hVpq293dZ7blYICvaoIUVPs55OYQkHHWUyGIplXpb0o=

/
show errors
create or replace
TYPE agg_tbl
  AS TABLE OF agg_attributes
/
show errors
CREATE OR REPLACE FUNCTION ridlist_tbl wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
8
b5 d6
SgwjFuAe5I2FdEr/9vJZWFbnBkAwgyrwAJlqyo7p2vjVuQQfawNe0y5Cyrv0q/KwZynThXeL
tV4u680QbhJyIU5UWgS7gQ07TxAxT7qchUSXRDr38FP3/0zvOmVJYPHavmN0+/dRKNsZa3In
pXjgRFnxZ8rUlNSPdBNQsdTK09U377Qj+eJKoGGBhjGkaROq3wqDzdvsd4e8wVaWwg==

/
show errors
CREATE OR REPLACE TYPE ridlist_tbl_stats_ot wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
d
196 138
Hgko5e4FTwePSWLF83MqKUK5mu0wgwLQrydqfHRAErlefbTmKZnSXbTysCW0NafLrVjwh+EC
NYb+sJ97wticiHQ8sNAPwnQAFQs0VcY+sOQyrl75R16S/3DDIoU3XMnS8SFm1vQv7JmjN1Vv
3d6xsvrjfCrF54eYOTppe8xfyAIr7ZSeHKwD9WColoU7LQQ4sbBclMPKywhU7bGp1ekxHYwW
+Kqs1dXEvgasHp9k67BE8QcBWgJdBbhU9MfcEOLEPr49kBL2MaVCn7Uab318g0X4ZNldxTC/
qrizGby+VU/frrmj3ko=

/
show errors
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
CREATE OR REPLACE PACKAGE solrresultset wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
9
48d 223
ysU0c1stWPaZi6PXlphRXuBVpocwg2MJ2UgVfC+Kvg8tgMhpPQkNdsDAimx/V5+gn4PAl/T9
CWwOtZqVNxRDPStU8n4xggu7R6fm/+lASzpxO7HZ17EnmJNINcOosZ6O3A3p4c27N4BUieeH
exV7GotL/a6iJy9ojn5cGtqsXM77KeEZNvpxUDClm1eIKLfcG7GTSM6Zg8kfPaMzTjCbe4j5
NWGPxogAgD+8nRYeH/mvPiah1YwQU9HaCu+L47dnIKJx0pW/M+Rn0rhzFa5xWntxOBWhKvqI
7fFuolzz5j6F73SDI9mjrSkLshkxoy/06aRgzb5khgtCjXsXabRMGVEGEh1ctO5+bQWwEqkA
8CO/Q+iTlZhxe4SI/FDmeQFZLEzkGEpw/8r/65eXDpACX+1wZ+oUwa86CAbITGodFWn3eb9y
fY61s61KtcPiCH1yrPCNEpDxoivnIps3Ido1V+nm1b5POS7Y7zDEl9CpBk9O7qdoeH1cwIax
sooGG58hQ+EsO+G7dH9Ygv4E8ZggT+XT2w==

/
show errors
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
