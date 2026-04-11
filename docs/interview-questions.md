# Cassandra Interview Q&A — Systematic Prep

## 1. NoSQL and Cassandra Basics
- What is NoSQL? How does Cassandra differ from relational databases?
- What are the main use cases for Cassandra?
- What is the CAP theorem, and where does Cassandra fit?

## 2. Core Cassandra Concepts
- What is a cluster, node, and data center in Cassandra?
- What is a partition key, and why is it critical?
  - It defines data placement and parallelism; choose it to evenly distribute load and bound partitions. Example:
    ```sql
    CREATE TABLE orders_by_user (
      user_id UUID,
      order_id TIMEUUID,
      amount decimal,
      PRIMARY KEY (user_id, order_id)
    );
    -- user_id is the partition key: all of a user's orders colocate; order_id clusters for ordering.
    ```
- How do clustering columns affect on-disk ordering and query patterns?
  - They sort rows within a partition and enable range queries. Order matters for filtering and paging.
    ```sql
    PRIMARY KEY (user_id, order_ts DESC, status)
    -- Enables queries like: SELECT * FROM ... WHERE user_id=? AND order_ts >= ? LIMIT 20;
    ```
- How does replication factor impact availability and reads/writes?
  - RF defines copies per DC. With RF=3 and CL=QUORUM, you can lose one node and still read/write. Higher RF improves availability at storage cost.
- What is tunable consistency? How do consistency levels work?
- What are common causes of hot partitions?
  - Skewed partition keys (e.g., country=US, date only), monotonically increasing keys, or small RF with high traffic.

## 3. Data Modeling and Querying
- Why is data modeled by query in Cassandra?
  - No joins; tables are shaped per access pattern to keep reads single-partition and predictable latency.
- When would you denormalize and duplicate data?
  - To serve multiple queries without ALLOW FILTERING or secondary indexes; storage is cheap, latency is not. Example (user lookup by email):
    ```sql
    CREATE TABLE users_by_id (
      user_id UUID PRIMARY KEY,
      email text,
      full_name text
    );
    CREATE TABLE users_by_email (
      email text,
      user_id UUID,
      full_name text,
      PRIMARY KEY (email, user_id)
    );
    ```
- How do you design tables for time-series data?
  - Use a compound key with a bounded time bucket to prevent wide partitions.
    ```sql
    CREATE TABLE readings_by_device (
      device_id UUID,
      day date,
      ts TIMEUUID,
      reading double,
      PRIMARY KEY ((device_id, day), ts)
    ) WITH CLUSTERING ORDER BY (ts DESC);
    ```
- What is the anti-pattern of using ALLOW FILTERING?
- How do you handle one-to-many and many-to-many relationships?

## 4. Indexes and Materialized Views
- When should you use a secondary index? When should you avoid it?
- What are materialized views? What are their pros and cons?
- How do you keep denormalized tables in sync?

## 5. Consistency, LWT, and Batching
- What is a lightweight transaction (LWT)?
- When should you use batches, and what are the pitfalls?
- What is the difference between logged and unlogged batches?

## 6. TTL, Tombstones, and Deletes
- What is TTL? How does it work in Cassandra?
- What are tombstones? Why can they be a problem?
- How does compaction interact with tombstones?

## 7. Aggregation, Filtering, and Counters
- Why is aggregation limited in Cassandra?
- What is the danger of using ALLOW FILTERING?
- How do counters work, and what are their caveats?

## 8. Advanced Topics
- What is a hot partition, and how do you avoid it?
- How does multi-DC replication work?
- What are some security features in Cassandra?
- How do you monitor and repair a Cassandra cluster?

---

Questions are mapped to the learning topics in labs-guide.md. For hands-on practice, see the corresponding lab for each topic.
