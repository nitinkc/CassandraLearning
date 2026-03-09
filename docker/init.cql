-- single-node dev
CREATE KEYSPACE IF NOT EXISTS cassandra_labs
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1};

-- used for spring-boot-cassandra-demo and subsequent labs; adjust replication strategy for multi-node clusters as needed
USE cassandra_labs;

CREATE TABLE IF NOT EXISTS users_by_id (
  user_id uuid,
  email text,
  full_name text,
  created_at timestamp,
  PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS users_by_email (
  email text,
  user_id uuid,
  full_name text,
  created_at timestamp,
  PRIMARY KEY ((email), user_id)
) WITH CLUSTERING ORDER BY (user_id ASC);

CREATE TABLE IF NOT EXISTS orders_by_user (
  user_id uuid,
  order_ts timestamp,
  order_id uuid,
  amount decimal,
  status text,
  PRIMARY KEY ((user_id), order_ts)
) WITH CLUSTERING ORDER BY (order_ts DESC);

INSERT INTO users_by_id (user_id, email, full_name, created_at)
VALUES (11111111-1111-1111-1111-111111111111, 'alex@example.com', 'Alex Chen', toTimestamp(now()));

INSERT INTO users_by_email (email, user_id, full_name, created_at)
VALUES ('alex@example.com', 11111111-1111-1111-1111-111111111111, 'Alex Chen', toTimestamp(now()));


--- SANDBOX: Additional keyspaces and tables for later labs (indexes, materialized views, multi-DC) ---

-- NetworkTopologyStrategy example (adjusted for local 2-node demo: datacenter1 RF=2)
CREATE KEYSPACE IF NOT EXISTS cassandra_labs_nets
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'datacenter1': 2
};
-- Multi-DC template (uncomment and adjust only if your cluster has these DC names):
-- CREATE KEYSPACE cassandra_labs_nets WITH replication = {
--   'class': 'NetworkTopologyStrategy',
--   'datacenter1': 3,
--   'dc2': 3
-- };

-- Tables for cassandra_labs_nets (multi-DC style)
USE cassandra_labs_nets;
CREATE TABLE IF NOT EXISTS nets_users_by_id (
  user_id uuid,
  email text,
  full_name text,
  created_at timestamp,
  PRIMARY KEY (user_id)
);
CREATE TABLE IF NOT EXISTS nets_orders_by_user (
  user_id uuid,
  order_ts timestamp,
  order_id uuid,
  amount decimal,
  status text,
  PRIMARY KEY ((user_id), order_ts)
) WITH CLUSTERING ORDER BY (order_ts DESC);

-- Return to default lab keyspace for subsequent statements
USE cassandra_labs;
