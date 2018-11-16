DECLARE
  stmt VARCHAR2(4000) := 'drop public synonym PushConnectorAdm';
BEGIN
  execute immediate stmt;
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
/
create or replace package PushConnectorAdm wrapped 
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
582 25c
4zhWDG2TgM0//WjGnhcN6nx3giAwg2PDr9yGfC9Vx53gSiaOqMMUyE0zfA2wO6gNkAh1TNyt
imZS+xSfOqqKoFCrY2mNFhh+HtcT/sl6CE3iUjWPD/lVCrDGxpgktU9BCLsdcIljsw7eSFZ/
cAT7Gr+zKgQamazThLBuG1M1KwxdoTLfiGpDrkst3uhE7L3WA5APZUCEpduKMB+/Uj8IiPW3
j9nnf9XAzKYlCCencXlBRtqQStPbA14a77ZNoj53YBjDQtzpznP/IkFvWtf/LKxO9x8IttRC
oPJZwPscrWmbjjQDN+U0puMl9QzzqvHEC3DxhWF6Yk5/DVUaXvATbEBvXwJ+EEkOO4B85GjS
OKVvC5DA+W+bMVtjHnbqvr5In+nyM2MjHzTWzRoUupxux/Ssw/cTO0EukMoPgF/w0nlV1Swj
OFhDhX1WZd6KsQGynjp8d0AzaV6a9TKiMCt1YDyek4h9zT/aBQwCzSMGxd9Ff6HyU7JJ3NUD
MbGPen8zGZo2PHx6BFNUOJcERvCXteNCxbdcjg7FWw5ADysHq1O1nsbKD2V+lrUIs9rtIkAa
feR8+5MAcwieGrBMgw==

/
show errors
grant execute on PushConnectorAdm to public
/
create public synonym PushConnectorAdm for PC.PushConnectorAdm
/
exit
