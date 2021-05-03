SET DEFINE OFF
-- search video
SELECT /*+ DOMAIN_INDEX_SORT */ id FROM OLS_TUTORIAL T where SCONTAINS(id,'video')>0;
-- search name:video
SELECT id FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'name:video')>0;
-- search +video +price:[* TO 400]
SELECT id,price FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'video AND price_f:[* TO 400]')>0;
-- search +video plus score
SELECT NAME,ID,round(SSCORE(1),2) FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'video',1)>0;
-- search 1 gigabyte matches things with GB
SELECT /*+ DOMAIN_INDEX_SORT */ round(SSCORE(1),2),NAME FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'"1GB"',1)>0;
-- Optimizer examples when doing domain index sort
SELECT ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'video',1)>0 order by price desc;
-- Domain Index sort, Optimizer Cost 3
SELECT /*+ DOMAIN_INDEX_SORT */ ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'video','price_f desc')>0;
-- pre-update test
SELECT ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'name:"Server-mod"')>0;
-- update test
UPDATE OLS_TUTORIAL SET id=id,NAME = 'Solr, the Enterprise Search Server-mod' WHERE ID='SOLR1000';
-- post-update test - call DBMS_LOCK.SLEEP(15)
SELECT ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'name:"Server-mod"')>0;
-- pre-delete by ID test
SELECT ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'name:SP2514N')>0;
-- delete by ID test
DELETE FROM OLS_TUTORIAL WHERE ID='SP2514N';
-- post-delete by ID test
SELECT ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'name:SP2514N')>0;
-- pre-delete by query test
SELECT ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'name:DDR')>0;
-- delete by Query test
DELETE FROM OLS_TUTORIAL WHERE SCONTAINS(id,'name:DDR')>0;
-- post-delete by query test
SELECT ID,NAME,PRICE FROM OLS_TUTORIAL WHERE SCONTAINS(ID,'name:DDR')>0;
-- Sort query example DESC
SELECT /*+ DOMAIN_INDEX_SORT */ ID,NAME,PRICE FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'video','price_f desc')>0;
-- Sort query example ASC
SELECT /*+ DOMAIN_INDEX_SORT */ ID,NAME,PRICE FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'video','price_f asc')>0;
-- Sort query example multiple columns
SELECT /*+ DOMAIN_INDEX_SORT */ ID,NAME,PRICE,INSTOCK FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'video','inStock_b asc,price_f desc')>0;
-- score desc natural sort for domain index
SELECT /*+ DOMAIN_INDEX_SORT */ round(SSCORE(1),2),ID,NAME FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'video',1)>0;
-- score can also be used as a field name when specifying a sort
SELECT /*+ DOMAIN_INDEX_SORT */ round(SSCORE(1),2),ID,NAME,PRICE,INSTOCK FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'video','inStock_b asc,score desc',1)>0;
-- Complex functions used to sort results - 1
SELECT /*+ DOMAIN_INDEX_SORT */ POPULARITY/(PRICE+1) PP,NAME FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'video','div(popularity_i,add(price_f,1)) desc',1)>0;
-- Highlight example
SELECT nvl(SHIGHLIGHT(1),name) hl,id FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'video card',1)>0;

SET SERVEROUTPUT ON
SET DEFINE OFF
SET LINESIZE 240
DECLARE
    obj      f_info; 
BEGIN
    -- Facets field simple example
    obj := SOLRPUSHCONNECTOR.facet('TUTORIAL_PIDX',null,'facet.field=cat');
    dbms_output.put_line(obj.fields.to_string);
    -- Facets field multiple example
    obj := SOLRPUSHCONNECTOR.facet('TUTORIAL_PIDX',null,'facet.field=cat&facet.field=inStock_b');
    dbms_output.put_line(obj.fields.to_string);
    -- Facets query example
    obj := SOLRPUSHCONNECTOR.facet('TUTORIAL_PIDX',null,'facet.query=price_f:[0+TO+100]&facet.query=price_f:[100+TO+*]');
    dbms_output.put_line(obj.queries.to_string);
    -- Facets dates example
    obj := SOLRPUSHCONNECTOR.facet('TUTORIAL_PIDX',null,'facet.range=manufacturedate_dt&facet.range.start=2004-01-01T00:00:00Z&facet.range.end=2010-01-01T00:00:00Z&facet.range.gap=%2B1YEAR');
    dbms_output.put_line(obj.ranges.to_string);
    -- Facets intervals example
    obj := SOLRPUSHCONNECTOR.facet('TUTORIAL_PIDX',null,'facet.interval=price_f&f.price_f.facet.interval.set=[0,10]&f.price_f.facet.interval.set=(10,100]');
    dbms_output.put_line(obj.intervals.to_string);
END;
/
-- Text analysis
SELECT /*+ DOMAIN_INDEX_SORT */ SSCORE(1),NAME,features FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'features:recharging',1)>0;
-- search misspelled pixima matches Pixma due to use of a SynonymFilter
SELECT /*+ DOMAIN_INDEX_SORT */ SSCORE(1),NAME FROM OLS_TUTORIAL T WHERE SCONTAINS(ID,'pixima',1)>0;
-- Geo-localization sort
SELECT /*+ DOMAIN_INDEX_SORT */ id,round(SSCORE(1),2) FROM OLS_TUTORIAL T where scontains(id,'video','geodist() asc&fq={!geofilt}&sfield=store_p&pt=37.7752,-100.0232&d=3000',1)>0;
-- Clean up
DROP TABLE OLS_TUTORIAL;

