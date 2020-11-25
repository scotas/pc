# Solr Push Connector for Oracle 18c
This the source Scotas Solr Push Connector(C)  for Oracle 18c (XE/Personal/EE editions).
To install a binary distribution on Oracle 18c XE Docker image just run:

```
$ git clone https://github.com/scotas/docker-images.git
$ cd docker-images
$ ./run-pc-18c.sh
```

it assumes that you already have an Oracle Docker image (**oracle/database:18.4.0-xe**) built using official
scripts from https://github.com/oracle/docker-images.git
Above command basically execute:

```
docker run -d --name pc --hostname pc \
  -e ORACLE_PWD=Oracle_2018 \
  -e SOLR_HOST=solr \
  -e SOLR_PORT=8983 \
  --link solr \
  -p 1521:1521 -p 8080:8080 \
  -v $PWD/pc-18cXE:/opt/oracle/scripts/setup \
  -v /home/data/db/xe-18c-pc:/opt/oracle/oradata \
  oracle/database:18.4.0-xe
```

where environments variables ORACLE_PWD, SOLR_HOST and SOLR_PORT are mandatory.

Local directory *$PWD/pc-18cXE* is a directory which just checkout from Scotas Docker images repo, */home/data/db/xe-18c-pc* is your
persistent directory where Oracle 18c XE Database will store the datafiles (chown 54321:54321).

Note that this Docker container is linked to an out-of-box Solr instance, start it using official Docker Solr images, for example:

```
$ docker run --name solr -d -p 8983:8983 -t solr 
```
## Built binary distribution from sources
An easy way to build a binary distribution from these sources is to start a linkded Docker container to running instance of Oracle 18c XE Database, for example
```
$ cd pc
$ docker run -ti --rm --name dev-pc-18c --hostname dev --link pc:ols \
    -v $PWD:/home/ols/pc \
    ols-dev:2.0.4
```
where **pc** is container running an Oracle 18c XE database.

# More info at [Scotas Push Connector Wiki](https://github.com/scotas/pc/wiki)
