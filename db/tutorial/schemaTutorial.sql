CREATE TABLE OLS_TUTORIAL (
  ID VARCHAR2(30) PRIMARY KEY,
  NAME VARCHAR2(400),
  MANU VARCHAR2(4000),
  CAT  VARCHAR2(400),
  FEATURES CLOB,
  INCLUDES VARCHAR2(4000),
  WEIGHT   NUMBER,
  PRICE    NUMBER,
  POPULARITY NUMBER,
  INSTOCK    CHAR(5), -- true or false
  MANUFACTUREDATE_DT TIMESTAMP,
  PAYLOADS   VARCHAR2(4000),
  STORE   VARCHAR2(200))
;

set define off
-- hd.xml
insert into ols_tutorial values (
'SP2514N',
'Samsung SpinPoint P120 SP2514N - hard drive - 250 GB - ATA-133',
'Samsung Electronics Co. Ltd.',
'["electronics", "hard-drive"]',
'7200RPM, 8MB cache, IDE Ultra ATA-133
NoiseGuard, SilentSeek technology, Fluid Dynamic Bearing (FDB) motor',
NULL,
NULL,
92,
6,
'true',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'35.0752,-97.032')
;
-- Near Oklahoma city

insert into ols_tutorial values (
'6H500F0',
'Maxtor DiamondMax 11 - hard drive - 500 GB - SATA-300',
'Maxtor Corp.',
'["electronics", "hard-drive"]',
'SATA 3.0Gb/s, NCQ
8.5ms seek
16MB cache',
NULL,
NULL,
350,
6,
'true',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'45.17614,-93.87341')
;
-- Buffalo store

-- ipod_other.xml
insert into ols_tutorial values (
'F8V7067-APL-KIT',
'Belkin Mobile Power Cord for iPod w/ Dock',
'Belkin',
'["electronics", "connector"]',
'car power adapter, white',
NULL,
4,
19.95,
1,
'false',
TO_TIMESTAMP('2005-08-01T16:30:25Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'45.18014,-93.87741')
;
-- Buffalo store

insert into ols_tutorial values (
'IW-02',
'iPod & iPod Mini USB 2.0 Cable',
'Belkin',
'["electronics", "connector"]',
'car power adapter for iPod, white',
NULL,
2,
11.50,
1,
'false',
TO_TIMESTAMP('2006-02-14T23:55:59Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'37.7752,-122.4232')
;
-- San Francisco store

-- ipod_video.xml
insert into ols_tutorial values (
'MA147LL/A',
'Apple 60 GB iPod with Video Playback Black',
'Apple Computer Inc.',
'["electronics", "music"]',
'iTunes, Podcasts, Audiobooks
Stores up to 15,000 songs, 25,000 photos, or 150 hours of video
2.5-inch, 320x240 color TFT LCD display with LED backlight
Up to 20 hours of battery life
Plays AAC, MP3, WAV, AIFF, Audible, Apple Lossless, H.264 video
Notes, Calendar, Phone book, Hold button, Date display, Photo wallet, Built-in games,
JPEG photo playback, Upgradeable firmware, USB 2.0 compatibility,
Playback speed control, Rechargeable capability, Battery level indication',
'earbud headphones, USB cable',
5.5,
399.00,
10,
'true',
TO_TIMESTAMP('2005-10-12T08:00:00Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'37.7752,-100.0232')
;
-- Dodge City store

-- mem.xml
insert into ols_tutorial values (
'TWINX2048-3200PRO',
'CORSAIR  XMS 2GB (2 x 1GB) 184-Pin DDR SDRAM Unbuffered DDR 400 (PC 3200) Dual Channel Kit System Memory - Retail',
'Corsair Microsystems Inc.',
'["electronics", "memory"]',
'CAS latency 2,	2-3-3-6 timing, 2.75v, unbuffered, heat-spreader',
NULL,
NULL,
185.00,
5,
'true',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
'electronics|6.0 memory|3.0',
'37.7752,-122.4232')
;
-- San Francisco store

insert into ols_tutorial values (
'VS1GB400C3',
'CORSAIR ValueSelect 1GB 184-Pin DDR SDRAM Unbuffered DDR 400 (PC 3200) System Memory - Retail',
'Corsair Microsystems Inc.',
'["electronics", "memory"]',
'CAS latency 2,	2-3-3-6 timing, 2.75v, unbuffered, heat-spreader',
NULL,
NULL,
74.99,
7,
'true',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
'electronics|4.0 memory|2.0',
'37.7752,-100.0232')
;
-- Dodge City store

insert into ols_tutorial values (
'VDBDB1A16',
'A-DATA V-Series 1GB 184-Pin DDR SDRAM Unbuffered DDR 400 (PC 3200) System Memory - OEM',
'A-DATA Technology Inc.',
'["electronics", "memory"]',
'CAS latency 3,	 2.7v',
NULL,
NULL,
NULL,
0,
'true',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
'electronics|0.9 memory|0.1',
'45.18414,-93.88141')
;
-- Buffalo store

-- monitor.xml
insert into ols_tutorial values (
'3007WFP',
'Dell Widescreen UltraSharp 3007WFP',
'Dell, Inc.',
'["electronics", "monitor"]',
'30" TFT active matrix LCD, 2560 x 1600, .25mm dot pitch, 700:1 contrast',
'USB cable',
401.6,
2199,
6,
'true',
NULL,
NULL,
'43.17614,-90.57341')
;
-- Buffalo store

-- monitor2.xml -- check this encoding problem with " in name column
insert into ols_tutorial values (
'VA902B',
'ViewSonic VA902B - flat panel display - TFT - 19"',
'ViewSonic Corp.',
'["electronics", "monitor"]',
'19" TFT active matrix LCD, 8ms response time, 1280 x 1024 native resolution',
NULL,
190.4,
279.95,
6,
'true',
NULL,
NULL,
'45.18814,-93.88541')
;
-- Buffalo store

-- mp500.xml
insert into ols_tutorial values (
'0579B002',
'Canon PIXMA MP500 All-In-One Photo Printer',
'Canon Inc.',
'["electronics", "multifunction-printer", "printer", "scanner", "copier"]',
'Multifunction ink-jet color photo printer
Flatbed scanner, optical scan resolution of 1,200 x 2,400 dpi
2.5" color LCD preview screen
Duplex Copying
Printing speed up to 29ppm black, 19ppm color
Hi-Speed USB
memory card: CompactFlash, Micro Drive, SmartMedia, Memory Stick, Memory Stick Pro, SD Card, and MultiMediaCard',
NULL,
352,
179.99,
6,
'true',
NULL,
NULL,
'45.19214,-93.89941')
;
-- Buffalo store

-- sd500.xml
insert into ols_tutorial values (
'9885A004',
'Canon PowerShot SD500',
'Canon Inc.',
'["electronics", "camera"]',
'3x zoop, 7.1 megapixel Digital ELPH
movie clips up to 640x480 @30 fps
2.0" TFT LCD, 118,000 pixels
built in flash, red-eye reduction',
'32MB SD card, USB cable, AV cable, battery',
6.4,
329.95,
7,
'true',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'45.19614,-93.90341')
;
-- Buffalo store

-- solr.xml
insert into ols_tutorial values (
'SOLR1000',
'Solr, the Enterprise Search Server',
'Apache Software Foundation',
'["software", "search"]',
'Advanced Full-Text Search Capabilities using Lucene
Optimized for High Volume Web Traffic
Standards Based Open Interfaces - XML and HTTP
Comprehensive HTML Administration Interfaces
Scalability - Efficient Replication to other Solr Search Servers
Flexible and Adaptable with XML configuration and Schema
Good unicode support: héllo (hello with an accent over the e)',
NULL,
NULL,
0,
10,
'true',
TO_TIMESTAMP('2006-01-17T00:00:00Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
NULL)
;

-- utf8-example.xml
insert into ols_tutorial values (
'UTF8TEST',
'Test with some UTF-8 encoded characters',
'Apache Software Foundation',
'["software", "search"]',
'No accents here
This is an e acute: é
eaiou with circumflexes: êâîôû
eaiou with umlauts: ëäïöü
tag with escaped chars: <nicetag/> ; end
escaped ampersand: Bonnie & Clyde',
NULL,
NULL,
0,
NULL, -- no popularity, get the default from schema.xml
'true',
NULL,
NULL,
NULL)
;

-- vidcard.xml
insert into ols_tutorial values (
'EN7800GTX/2DHTV/256M',
'ASUS Extreme N7800GTX/2DHTV (256 MB)',
'ASUS Computer Inc.',
'["electronics", "graphics-card"]',
'NVIDIA GeForce 7800 GTX GPU/VPU clocked at 486MHz
256MB GDDR3 Memory clocked at 1.35GHz
PCI Express x16
Dual DVI connectors, HDTV out, video input
OpenGL 2.0, DirectX 9.0',
NULL,
16,
479.95,
7,
'false',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'40.7143,-74.006')
;

-- NYC store
insert into ols_tutorial values (
'100-435805',
'ATI Radeon X1900 XTX 512 MB PCIE Video Card',
'ATI Technologies',
'["electronics", "graphics-card"]',
'ATI RADEON X1900 GPU/VPU clocked at 650MHz
512MB GDDR3 SDRAM clocked at 1.55GHz
PCI Express x16
dual DVI, HDTV, svideo, composite out
OpenGL 2.0, DirectX 9.0',
NULL,
48,
649.99,
7,
'false',
TO_TIMESTAMP('2006-02-13T15:26:37Z','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
NULL,
'40.7143,-74.006')
;
-- NYC store

commit;

/*
-- Minimun change at Solr schema in order to PC works
$ bin/solr create_core -c tutorial

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
}' http://localhost:8983/solr/tutorial/schema

$ sed -i 's/<uniqueKey>id/<uniqueKey>rowid/g' /var/solr/data/tutorial/conf/managed-schema
$ curl "http://localhost:8983/solr/admin/cores?action=RELOAD&core=tutorial"

-- Tutorial custom
$ curl -X POST -H 'Content-type:application/json' --data-binary '{
  "add-field":{
     "name":"title",
     "type":"text_general",
     "indexed":true,
     "stored":true,
     "multiValued":true
  },
  "add-field":{
     "name":"text",
     "type":"text_en_splitting",
     "indexed":true,
     "stored":false,
     "multiValued":true
  },
  "add-field":{
     "name":"features",
     "type":"text_en_splitting",
     "indexed":true,
     "stored":true,
     "multiValued":true
  },
  "add-field":{
     "name":"text_rev",
     "type":"text_general_rev",
     "indexed":true,
     "stored":false,
     "multiValued":true
  },
  "add-copy-field" :{
     "source":"*",
     "dest":"_text_"
  }
}' http://localhost:8983/solr/tutorial/schema

*/
-- indexing
CREATE INDEX TUTORIAL_PIDX ON OLS_TUTORIAL(ID) INDEXTYPE IS PC.SOLR
  PARAMETERS('{NormalizeScore:true,
               LogLevel:"INFO",
               Updater:"solr@8983",
               Searcher:"solr@8983",
               SolrBase:"solr/tutorial",
               CommitOnSync:true,
               SyncMode:"OnLine",
               BatchCount:5,
               LockMasterTable:false,
               IncludeMasterColumn:false,
               HighlightColumn:"name,features",
               MltColumn:"name",
               DefaultColumn:"_text_",
               ExtraCols:"''id'' value id, ''cat'' value cat FORMAT JSON, ''name'' value name, ''features'' value features, ''manu'' value manu, ''includes'' value includes, ''price_f'' value price, ''popularity_i'' value popularity, ''inStock_b'' value trim(inStock) FORMAT JSON, ''manufacturedate_dt'' value manufacturedate_dt, ''store_p'' value store"}')
;
