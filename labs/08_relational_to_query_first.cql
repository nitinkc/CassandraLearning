-- Lab 08: Converting a relational model to query-first (step-by-step)
-- Run this file in the running cluster (copy into container or mount) after the two-node compose is up.

-- 1) Keyspace for labs (SimpleStrategy for local dev)
CREATE KEYSPACE IF NOT EXISTS cassandra_labs
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE cassandra_labs;

-- 2) Create users_by_id (lookup by user id)
CREATE TABLE IF NOT EXISTS users_by_id (
  user_id uuid PRIMARY KEY,
  email text,
  full_name text,
  created_at timestamp
);

-- 3) Create users_by_email (lookup table for email -> users)
CREATE TABLE IF NOT EXISTS users_by_email (
  email text,
  user_id uuid,
  full_name text,
  created_at timestamp,
  PRIMARY KEY ((email), user_id)
) WITH CLUSTERING ORDER BY (user_id ASC);

-- 4) Create orders_by_user (ordered recent-first by order_ts)
CREATE TABLE IF NOT EXISTS orders_by_user (
  user_id uuid,
  order_ts timestamp,
  order_id uuid,
  amount decimal,
  status text,
  PRIMARY KEY ((user_id), order_ts)
) WITH CLUSTERING ORDER BY (order_ts DESC);

-- 5) Example dual-write flow using a logged batch (atomic across the tables in this batch)
BEGIN LOGGED BATCH
  INSERT INTO users_by_id (user_id, email, full_name, created_at)
  VALUES (22222222-2222-2222-2222-222222222222, 'sam@example.com', 'Sam Lee', toTimestamp(now()));
  INSERT INTO users_by_email (email, user_id, full_name, created_at)
  VALUES ('sam@example.com', 22222222-2222-2222-2222-222222222222, 'Sam Lee', toTimestamp(now()));
  INSERT INTO orders_by_user (user_id, order_ts, order_id, amount, status)
  VALUES (22222222-2222-2222-2222-222222222222, toTimestamp(now()), uuid(), 49.99, 'PLACED');
APPLY BATCH;

-- 6) Sample queries (fast, partition-scoped)
SELECT * FROM users_by_id WHERE user_id = 22222222-2222-2222-2222-222222222222;
SELECT * FROM users_by_email WHERE email = 'sam@example.com';
SELECT * FROM orders_by_user WHERE user_id = 22222222-2222-2222-2222-222222222222 LIMIT 10;

-- 7) NTS example (for multi-DC demos, create only when DC names exist):
-- CREATE KEYSPACE IF NOT EXISTS cassandra_labs_nets WITH replication = {'class':'NetworkTopologyStrategy', 'datacenter1':2};


