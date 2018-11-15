package com.scotas.solr.indexer;

import java.io.IOException;

import java.math.BigDecimal;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

import java.util.Random;

import junit.framework.TestCase;

import oracle.jdbc.pool.OracleDataSource;


/*
 * Stress test queries, requires a table created as 
 *    (connected as sys and changed to scott schema):
 * SQL> create table test_source_big as (select * from all_source);
 * Index definition should be:
 * SQL> create index source_big_idx on test_source_big(text)
        indextype is ctxsys.context
        filter by type,line
        order by line desc
        parameters('SYNC (MANUAL) TRANSACTIONAL');
 */
public class TestQueryHitsCtx extends TestCase {
    private static int MAX_THREADS = 5;
    private static int NUM_READS = 20;
    private static final Random RANDOM = new Random();
    private Thread[] ts = new Thread[MAX_THREADS];

    private static final String qry = "function OR procedure OR package";

    OracleDataSource ods = null;
    long startTime = 0;

    private static int random(int i) { // for JDK 1.1 compatibility
        int r = RANDOM.nextInt();
        if (r < 0)
            r = -r;
        return r % i;
    }

    private void iterateOverResult(int from, boolean firstRowHint, boolean getScore) throws IOException, SQLException {
        PreparedStatement psmt = null;
        ResultSet rs = null;
        Connection conn = null;
        try {
            conn = ods.getConnection();
            psmt = conn.prepareStatement(
            " select sc,text from (" +
            " select rownum as ntop_pos,q.* from (" +
            " select /*+ "+ ((firstRowHint) ? "FIRST_ROWS" : "") +" DOMAIN_INDEX_SORT DOMAIN_INDEX_FILTER(test_source_big source_big_idx) */ "+
            ((getScore) ? "score(1)" : "-1") +" sc,text\n" +
            " from test_source_big where contains(text,?,1)>0 and type='PACKAGE BODY' and line between 0 and 3000 order by line DESC" +
            " ) q)" +
            " where ntop_pos>=? and ntop_pos<=?" );
            psmt.setString(1, qry);
            psmt.setInt(2, from);
            psmt.setInt(3, from + 9);
            long stepTime = System.currentTimeMillis();
            rs = psmt.executeQuery();
            System.out.println("Query time: " +
                               (System.currentTimeMillis() - stepTime));
            //System.out.println("iteration from: " + from + " to: " +
            //                   (from + 10));
            while (rs.next()) {
                float score = rs.getFloat(1);
                String str = rs.getString(2);
                //System.out.println("Score: " + score + " str: " + str);
            }
            rs.close();
            rs = null;
        } catch (SQLException s) {
            System.err.println("SQLError processing from row="+from+" msg= "+
                               s.getLocalizedMessage()+" errorCode="+
                               s.getErrorCode()+" sqlState="+s.getSQLState());
            s.printStackTrace();
        } finally {
            if (rs != null)
                rs.close();
            rs = null;
            if (psmt != null)
                psmt.close();
            psmt = null;
            if (conn != null)
                conn.close();
            conn = null;
        }
    }

    public TestQueryHitsCtx() throws SQLException {
        ods = new OracleDataSource();
        java.util.Properties prop = new java.util.Properties();
        prop.setProperty("MinLimit", "2");
        prop.setProperty("MaxLimit", "10");
        // set DataSource properties
        //String url = "jdbc:oracle:oci8:@CSDS1";
        //            String url = "jdbc:oracle:thin:@mppdbx01.generali.it:1622:CSDK1";
        //            String url = "jdbc:oracle:thin:@mppdbx01.generali.it:1626:CSDS1";
        //            String url = "jdbc:oracle:thin:@(DESCRIPTION =(ADDRESS_LIST =(ADDRESS = (PROTOCOL = TCP)(HOST = mppdbx01.generali.it)(PORT = 1626)) ) (CONNECT_DATA = (SERVER = DEDICATED) (SID = CSDS1) ) )";
        String url =
            "jdbc:oracle:thin:@" + System.getProperty("db.str", "pc:1521/xepdb1");
        ods.setURL(url);
        ods.setUser(System.getProperty("db.usr", "PC"));
        ods.setPassword(System.getProperty("db.pwd", "PC"));
        ods.setConnectionCachingEnabled(true); // be sure set to true
        ods.setConnectionCacheProperties(prop);
        //ods.setConnectionCacheName("ImplicitCache01"); // this cache's name
    }

    private int countHits() throws SQLException {
        CallableStatement myCallableStatement = null;
        BigDecimal result = new BigDecimal(0);
        Connection conn = null;
        try {
            conn = ods.getConnection();
            myCallableStatement =
                    conn.prepareCall("{ ? = call ctx_query.count_hits(index_name => ?, text_query => ?, exact => TRUE) }");
            myCallableStatement.registerOutParameter(1, Types.BIGINT);
            myCallableStatement.setString(2, "SOURCE_BIG_IDX");
            myCallableStatement.setString(3, qry);
            myCallableStatement.execute();
            result = myCallableStatement.getBigDecimal(1);
            System.out.println("Hits: " + result);
        } catch (SQLException s) {
            s.printStackTrace();
        } finally {
          if (myCallableStatement != null)
              myCallableStatement.close();
          myCallableStatement = null;
          if (conn != null)
              conn.close();
          conn = null;
        }
        return result.intValue();
    }

    /**
     * This test case requires a table created as:
     * create table test_source_big as (select * from all_source);
     * Index is for 10g:
        create index source_big_idx on test_source_big(text)
        indextype is ctxsys.context;
     * For 11g/12c/18c:
        create index source_big_idx on test_source_big(text)
        indextype is ctxsys.context
        filter by line
        order by line;
     * @throws IOException
     * @throws SQLException
     */
    public void setUp() throws IOException, SQLException {
        startTime = System.currentTimeMillis();
    }


    public void testHits() throws IOException, SQLException {
        countHits();
    }

    /**
     * Simulate multiple calls from middle tier enviroment
     * each call get a new connection from DataSource connection pool
     * @throws IOException
     * @throws SQLException
     */
    public void testLoop() throws IOException, SQLException,
                                  InterruptedException {
        for (int i = 0; i < MAX_THREADS; i++) {
            ts[i] = new Thread("Searcher " + i) {
                        public void run() {
                            int totalRows;
                        try {
                            totalRows = (int)(countHits() * 0.40);
                        } catch (SQLException e) {
                            e.printStackTrace();
                            throw new RuntimeException(e);
                        }
                        int row = 1;
                            for (int j = 0; j < NUM_READS; j++)
                                try {
                                    int waitTime = random(10);
                                    row =
                                        ((random(totalRows) / 100) * 2) + 1;
                                    //System.out.println(this +
                                    //                   " searching window " +
                                    //                   row);
                                    iterateOverResult(row+1,false,false);
                                    sleep(100 * waitTime);
                                } catch (InterruptedException e) {
                                    e.printStackTrace();
                                    throw new RuntimeException(e);
                                } catch (IOException e) {
                                    e.printStackTrace();
                                } catch (SQLException e) {
                                    e.printStackTrace();
                                }
                        }

                        public String toString() {
                            return getName();
                        }
                    };
            ts[i].start();
        }
        for (int i = 0; i < MAX_THREADS; i++) {
            ts[i].join();
        }
    }

    public void tearDown() throws IOException, SQLException {
        System.out.println("Elapsed time: " +
                           (System.currentTimeMillis() - startTime));
    }
}
