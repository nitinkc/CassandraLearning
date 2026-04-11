# Cassandra CQL Labs — Guided Learning Path

## Cassandra Learning Topics (Systematic Interview Prep)

### 1. Introduction to NoSQL and Cassandra
- What is NoSQL? Types of NoSQL databases
- Cassandra’s architecture and use cases
- CAP theorem and Cassandra’s trade-offs

### 2. Core Cassandra Concepts
- Cluster, node, data center
- Partitioning: partition key, token ring, data distribution
- Clustering columns: on-disk order, range queries
- Replication: replication factor, consistency levels
- Hinted handoff, read/write path, tunable consistency
- Lab: 01_keyspace_basics.cql, 02_partitioning_clustering.cql

### 3. Data Modeling in Cassandra
- Query-first design: denormalization, query-based tables
- Primary key design: single vs. composite keys
- Wide rows, time-series modeling, bounding partitions
- Lab: 03_modeling_by_query.cql

### 4. Indexes and Materialized Views
- Secondary indexes: pros, cons, and anti-patterns
- Materialized views: use cases and limitations
- Lab: 04_indexes_and_mv.cql

### 5. Consistency, Lightweight Transactions, and Batching
- Consistency levels: ONE, QUORUM, ALL, LOCAL_QUORUM, etc.
- Lightweight transactions (LWT): compare-and-set, use cases
- Batching: atomicity, pitfalls
- Lab: 05_consistency_lwt_batch.cql

### 6. TTL, Tombstones, and Deletes
- TTL (time-to-live): expiring data
- Tombstones: delete markers, compaction, anti-patterns
- Lab: 06_ttl_tombstones.cql

### 7. Aggregation, Filtering, and Counters
- Aggregation limitations, ALLOW FILTERING, paging
- Counters: use cases and caveats
- Lab: 07_aggregation_filtering.cql

### 8. Advanced Topics
- Data distribution, hot partitions, anti-patterns
- Multi-DC replication, network topology
- Security basics: authentication, authorization
- Monitoring and repair basics
- Placeholder: Add labs for advanced topics as needed (e.g., multi-DC, security)

---

These topics are mapped to the hands-on labs below. For each topic, review the theory, then complete the corresponding lab for practical understanding.

Environment (assumptions)
- Cassandra 5.x (local Docker-based labs).
- Java 21 / Spring Boot app lives in `spring-boot-app/` (used separately from the labs).
- Schema and initialization live under `scripts/` and `labs/`.
- Conventions: schema uses query-first denormalized tables; each lab uses `IF NOT EXISTS` so it is safe to re-run.

Quick start
- Start the Docker Cassandra setup (from project root):

```bash
# start the cluster as defined in scripts/docker-compose.yml
docker compose -f scripts/docker-compose.yml up -d
```

- Run a lab file inside the running Cassandra container. 
- Note: the container does not automatically see your host `labs/` files unless they are mounted. Two safe options:

1) Use the provided init script (if present) that is already copied into the container:

```bash
# this runs the combined init that the container exposes (if scripts/init.cql exists)
docker compose -f scripts/docker-compose.yml exec cassandra cqlsh -f /init/init.cql
```

2) Copy an individual lab file into the container and run it there (recommended when iterating on a single lab):

```bash
# copy a file into the container, then run it with cqlsh
docker cp labs/01_keyspace_basics.cql $(docker compose -f scripts/docker-compose.yml ps -q cassandra):/tmp/01_keyspace_basics.cql
docker compose -f scripts/docker-compose.yml exec cassandra cqlsh -f /tmp/01_keyspace_basics.cql
```

Note: using `-f /labs/01_keyspace_basics.cql` directly fails when the container has no `/labs` mount ("No such file or directory").
Use the copy approach or update your compose file to mount the project root into the container.

Lab order (do not change — learning path is intentional)
1. `01_keyspace_basics.cql` — keyspace creation, SimpleStrategy, first table
2. `02_partitioning_clustering.cql` — partitioning and clustering keys; bounding partitions
3. `03_modeling_by_query.cql` — query-driven modeling and lookup tables (dual-write)
4. `04_indexes_and_mv.cql` — secondary indexes and materialized views (trade-offs)
5. `05_consistency_lwt_batch.cql` — consistency levels, lightweight transactions, batches
6. `06_ttl_tombstones.cql` — TTLs, tombstones, delete behavior, compaction notes
7. `07_aggregation_filtering.cql` — aggregation, ALLOW FILTERING caution, counters/aggregation patterns

Per-lab, table-by-table explanation and purpose

Lab 01 — Keyspace basics (`01_keyspace_basics.cql`)
- Keyspace: `cassandra_labs` created with `SimpleStrategy` replication_factor=1.
  - Why: fastest for single-node local dev. Simpler startup and predictable behavior for learning.
  - Alternatives: `NetworkTopologyStrategy` (NTS) for multi-DC setups (see "Replication strategies" below). Use RF >= 3 per DC in production.
- Table: `products_by_id`
  - Columns: `product_id` (uuid PK), `name`, `category`, `price`, `created_at`.
  - Primary key: simple primary key on `product_id` (good when access is by id). No clustering columns.
  - Demonstrates: basic inserts, selects, and TTL usage via UPDATE ... USING TTL to show TTL semantics.

Lab 02 — Partitioning and clustering (`02_partitioning_clustering.cql`)
- Table: `events_by_day`
  - PK: `((event_day), event_ts)` — partition key = `event_day`, clustering = `event_ts`.
  - Purpose: show distribution by day and ordered reads (recent-first using DESC clustering order).
  - Trade-offs: using only day as partition key can produce hot/unbounded partitions for high traffic; show time bucketing.
- Table: `events_by_day_hour`
  - PK: `((event_day, hour_bucket), event_ts)` — adds `hour_bucket` to cap partition size.
  - Purpose: demonstrates explicit bucketing to prevent hot partitions and to bound reads.

Lab 03 — Modeling by query (`03_modeling_by_query.cql`)
- Concept: design tables for access patterns rather than normalized relational joins.
- Table: `users_by_id`
  - PK: `user_id` (read by id).
- Table: `users_by_email`
  - PK: `((email), user_id)` (lookup by email, supports multiple users per email if needed).
  - Purpose: show denormalization; keep lookup tables synchronized via dual-writes or batches (example shows a logged batch).
  - Anti-pattern: don't scan `users_by_id` by email — that requires ALLOW FILTERING and is inefficient.

Lab 04 — Indexes and materialized views (`04_indexes_and_mv.cql`)
- Secondary index on `users_by_id(email)`
  - When to use: low-cardinality columns, queries that target small partitions; avoid for fan-out across many partitions.
- Materialized view `users_by_email_mv`
  - Why shown: server-side denormalization to support a query without dual-writes.
  - Caveats: MVs can drift and add repair cost; modern practice prefers explicit dual-writes from application code.

Lab 05 — Consistency, LWT, and batching (`05_consistency_lwt_batch.cql`)
- Demonstrates `CONSISTENCY` setting (the file uses `CONSISTENCY ONE` for dev).
- LWT examples (`IF NOT EXISTS`, `IF full_name = ...`) — explains Paxos cost and when to use.
- Logged vs Unlogged batch: shows atomic multi-table writes (logged) and performance-minded unlogged batches.

Lab 06 — TTL and tombstones (`06_ttl_tombstones.cql`)
- Table: `sessions_by_user` with TTLed inserts and explicit deletes.
- Teaches: TTL generates tombstones; high-churn patterns can cause read/compaction performance issues.
- Advice: don't lower `gc_grace_seconds` in prod without understanding repair; for local tests you may shorten it to observe tombstone cleanup.

Lab 07 — Aggregation and filtering (`07_aggregation_filtering.cql`)
- Shows that `COUNT(*)` over the entire cluster is a full scan — only safe when used per-partition.
- `ALLOW FILTERING` is included to demonstrate a dangerous pattern and reinforce proper modeling (use lookup tables or pre-aggregated counters).

Replication strategies — SimpleStrategy vs NetworkTopologyStrategy
- SimpleStrategy
  - Intended for single-DC deployments and local development only.
  - Example usage in labs: fast startup and minimal operational complexity.
  - Not suitable for multi-DC because it places replicas by token range only.
- NetworkTopologyStrategy (NTS)
  - Specify per-DC replication factors: e.g. `{'class':'NetworkTopologyStrategy', 'dc1':3, 'dc2':3}`.
  - Use when you have multiple data centers (cloud regions or physical DCs). Recommended RF per DC: 3 for typical production (lets you survive rack/node failures while maintaining quorum).
  - Testing vs Prod: In testing (single-host Docker) set RF=1 or 2 to save resources; in realistic prod demos use RF=3 per DC and run multiple nodes per DC.

Practical demo notes for multi-DC / racks
- For a richer multi-DC demo: spin up nodes labeled for each DC (container hostnames or container labels) and set RF per DC in the keyspace. Racks can remain implicit for a lab. Example: create multiple containers, set `broadcast_address` and `seed_provider` appropriately, and create keyspace with NTS specifying the DC names you used.
- For learning purposes the labs include a `cassandra_labs_nets` NTS example; ensure your compose and init scripts create matching DC names (the error "Unrecognized strategy option {dc2}" usually means the keyspace was created with a DC name that Cassandra does not know about — make sure your cluster defines that DC).

Common troubleshooting (concise)
- "Can't open 'labs/01_keyspace_basics.cql'": container has no `/labs` mount. Use `docker cp` into container or mount the repository root in docker-compose.
- `AlreadyExists: Keyspace ... already exists`: safe; the CQL files use `IF NOT EXISTS`. You can skip or edit to DROP if you want to reset.
- "Seed provider lists no seeds" on startup: your cassandra.yaml seed provider lists hostnames the node cannot resolve (e.g., `cassandra`). Ensure container names match the seed list or use IPs. In docker-compose use service name as hostname and ensure networks are correct. For two-rack demos, make sure at least one node lists a valid seed.
- `socket.gaierror: [Errno -2] Name or service not known` when running init container: the init script attempted to contact a host that doesn't resolve. Use the container name from `docker compose ps` or the container IP.

Docs and story (why these labs exist)

- Story: start with the simplest unit — keyspace and single-table reads by id 
- then introduce partitioning/clustering (how data is distributed and ordered), 
- then move to modeling by query (the core Cassandra mindset), 
- followed by optional server-side helpers (indexes/MV) and operational features (consistency, LWT, batching, TTL/tombstones), 
- and finally aggregation and filtering pitfalls. Each lab intentionally introduces a small, testable concept and shows both the correct patterns and common anti-patterns you'd encounter in interviews.

Notes from the Copilot context (project conventions)
- This repo is intentionally query-first and denormalized.
- Keep the learning path (lab order) unchanged — the labs build on each other.
- Use `scripts/init.cql` for a consolidated init; if you prefer per-lab runs, run the specific lab files by copying them into the container as shown above.

If you'd like next steps I can:
- Consolidate `scripts/init.cql` and the individual `labs/*.cql` into a single `scripts/init.cql` (or remove duplicates) and update `docker-compose.yml` to mount the repository so you can run `cqlsh -f /labs/01_keyspace_basics.cql` directly from the container. (I can implement this now if you want.)
- Add a short appendix with command examples for copying files into the container, or update `scripts/docker-compose.yml` to mount the repo.

Why query-first (concise)
- What it means: instead of modeling data around normalized entities and joins, you model tables around the queries your application needs to run. Each table is designed so a target query touches a single partition and returns results with predictable latency.
- Why this repo: Cassandra is optimized for high write throughput and fast single-partition reads. Denormalization (storing the same logical data in multiple tables) keeps reads simple and fast at the cost of extra storage and write coordination.

Quick mapping to the labs
- Lab 03 (`users_by_id` + `users_by_email`) demonstrates the canonical pattern: one table per access pattern. Reads by id and reads by email hit different tables designed for those access patterns.
- Lab 02 shows partition bucketing to avoid hot partitions — a common operational technique when query-first tables may otherwise grow unbounded.

Step-by-step example — converting a relational model to query-first
- Relational (example): a single `users` table and an `orders` table, and an application that needs:
  1) Get user by id
  2) Get user by email
  3) Get orders for a user (most recent first)

Relational schema (conceptual):
- users(id PK, email unique, full_name, created_at)
- orders(id PK, user_id FK -> users.id, created_at, amount, status)

Problems on Cassandra if you keep this relational layout:
- "Get user by email" requires a full-table scan or secondary index (not ideal at scale).
- "Get orders for a user" is doable if `orders` is partitioned by user, but joining across tables is an anti-pattern.

Query-first conversion (concrete CQL examples — also available in `docker/init.cql` and `labs/08_relational_to_query_first.cql`):

1) users_by_id — look up by id
CREATE TABLE IF NOT EXISTS users_by_id (
  user_id uuid PRIMARY KEY,
  email text,
  full_name text,
  created_at timestamp
);

2) users_by_email — lookup table to answer email->user_id efficiently
CREATE TABLE IF NOT EXISTS users_by_email (
  email text,
  user_id uuid,
  full_name text,
  created_at timestamp,
  PRIMARY KEY ((email), user_id)
) WITH CLUSTERING ORDER BY (user_id ASC);

3) orders_by_user — serve the "get orders for a user" access pattern (recent first)
CREATE TABLE IF NOT EXISTS orders_by_user (
  user_id uuid,
  order_ts timestamp,
  order_id uuid,
  amount decimal,
  status text,
  PRIMARY KEY ((user_id), order_ts)
) WITH CLUSTERING ORDER BY (order_ts DESC);

Typical application write flow (dual-write / batch):
- When creating an order, write to `orders_by_user` and also record any additional helper tables required by queries.
- Example logged batch (atomic across tables):
BEGIN LOGGED BATCH
  INSERT INTO orders_by_user (user_id, order_ts, order_id, amount, status) VALUES (1111..., toTimestamp(now()), uuid(), 129.99, 'PLACED');
  -- if you had another table for order lookup by id, write it here
APPLY BATCH;

Common queries and their CQL (fast, partition-scoped):
- Get user by id: SELECT * FROM users_by_id WHERE user_id = <uuid>;
- Get users by email: SELECT * FROM users_by_email WHERE email = '<email>';
- List recent orders for a user: SELECT * FROM orders_by_user WHERE user_id = <uuid> LIMIT 20;

Why this aligns with the Spring models in this repo
- The `OrderByUser` model in `spring-boot-app` maps directly to `orders_by_user` above: the PK is the `user_id` partition with `order_ts` clustering for ordering. Writing/reading in the service layer should target these tables directly (dual-writes for any additional lookup tables).

Orders table notes (practical)
- Use time-based clustering columns (`order_ts` or timeuuid) so reads for recent orders are efficient and bounded.
- If a user can generate a very large number of orders, consider adding a bucket (e.g., year_month) to the partition key to bound partition size.

2-node docker-compose demo and NTS keyspaces (how-to)
- The project includes a `docker/docker-compose.yml` demo for two local nodes. Important points to make NTS keyspaces work:
  - Each Cassandra node must agree on seed hostnames; set `CASSANDRA_SEEDS` to a comma-separated list of seed hostnames that are resolvable inside the Docker network (e.g., `cassandra,cassandra2`).
  - When creating a `NetworkTopologyStrategy` keyspace, the DC names you use in the keyspace replication map must match the node-configured DC names (environment variable `CASSANDRA_DC`). The compose file sets `CASSANDRA_DC` for each node.
  - For a 2-node lab/demo set RF=2 for the DC you create in `init.cql` (so replication fits the available nodes). For a production demo use RF=3 and run more nodes.

Example: to create a 2-node NTS-friendly keyspace for local demos:
CREATE KEYSPACE IF NOT EXISTS cassandra_labs_nets WITH replication = {'class':'NetworkTopologyStrategy', 'datacenter1': 2};

Troubleshooting seeds and hostnames
- If a node fails with "Seed provider couldn't lookup host cassandra" or "The seed provider lists no seeds":
  - Check service hostnames in `docker compose ps` and ensure they match `CASSANDRA_SEEDS` entries.
  - Ensure any entry that lists a DC name in the keyspace uses exactly the same DC value present in node environment variables.

# Cassandra Tutorial: From Basics to Advanced (with Self-Check Questions)

### 1. NoSQL and Cassandra Basics
Cassandra is a distributed NoSQL database designed for high availability and scalability. Unlike relational databases, Cassandra uses a flexible schema and is optimized for fast writes and horizontal scaling.

**Key Concepts:**
- NoSQL databases: schema-less, distributed, designed for scale
- Cassandra’s architecture: peer-to-peer, decentralized
- CAP theorem: Cassandra favors Availability and Partition tolerance (AP)

**Self-Check:**
- What is NoSQL? How does Cassandra differ from relational databases?
- What are the main use cases for Cassandra?
- What is the CAP theorem, and where does Cassandra fit?

---

### 2. Core Cassandra Concepts
Cassandra clusters consist of nodes grouped into data centers. Data is distributed using partition keys and replicated for fault tolerance.

**Key Concepts:**
- Cluster, node, data center
- Partition key: determines data placement and distribution
- Clustering columns: define on-disk order within a partition
- Replication factor: number of copies per data center
- Consistency levels: control read/write guarantees

**Example:**
```sql
CREATE TABLE orders_by_user (
  user_id UUID,
  order_id TIMEUUID,
  amount decimal,
  PRIMARY KEY (user_id, order_id)
);
```
- Here, `user_id` is the partition key; `order_id` is a clustering column.

**Self-Check:**
- What is a cluster, node, and data center in Cassandra?
- What is a partition key, and why is it critical?
- How do clustering columns affect on-disk ordering and query patterns?
- How does replication factor impact availability and reads/writes?
- What is tunable consistency? How do consistency levels work?
- What are common causes of hot partitions?

**Lab:** 01_keyspace_basics.cql, 02_partitioning_clustering.cql

---

### 3. Data Modeling and Querying
Cassandra uses query-first, denormalized data modeling. Tables are designed for specific queries, not for normalization.

**Key Concepts:**
- Query-first design: one table per access pattern
- Denormalization: duplicate data for fast reads
- Wide rows: use clustering columns for time-series or ordered data

**Example:**
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

**Self-Check:**
- Why is data modeled by query in Cassandra?
- When would you denormalize and duplicate data?
- How do you design tables for time-series data?
- What is the anti-pattern of using ALLOW FILTERING?
- How do you handle one-to-many and many-to-many relationships?

**Lab:** 03_modeling_by_query.cql

---

### 4. Indexes and Materialized Views
Cassandra supports secondary indexes and materialized views, but both have trade-offs and should be used carefully.

**Key Concepts:**
- Secondary indexes: best for low-cardinality, small partitions
- Materialized views: server-side denormalization, but can drift

**Example:**
```sql
CREATE INDEX ON users_by_id(email);
CREATE MATERIALIZED VIEW users_by_email_mv AS
  SELECT * FROM users_by_id
  WHERE email IS NOT NULL AND user_id IS NOT NULL
  PRIMARY KEY (email, user_id);
```

**Self-Check:**
- When should you use a secondary index? When should you avoid it?
- What are materialized views? What are their pros and cons?
- How do you keep denormalized tables in sync?

**Lab:** 04_indexes_and_mv.cql

---

### 5. Consistency, Lightweight Transactions, and Batching
Cassandra offers tunable consistency and supports lightweight transactions (LWT) for conditional updates. Batching can be used for atomic multi-table writes.

**Key Concepts:**
- Consistency levels: ONE, QUORUM, ALL, LOCAL_QUORUM, etc.
- LWT: compare-and-set, uses Paxos protocol
- Batching: logged (atomic), unlogged (performance)

**Example:**
```sql
BEGIN LOGGED BATCH
  INSERT INTO users_by_id (user_id, email, full_name) VALUES (...);
  INSERT INTO users_by_email (email, user_id, full_name) VALUES (...);
APPLY BATCH;
```

**Self-Check:**
- What is a lightweight transaction (LWT)?
- When should you use batches, and what are the pitfalls?
- What is the difference between logged and unlogged batches?

**Lab:** 05_consistency_lwt_batch.cql

---

### 6. TTL, Tombstones, and Deletes
Cassandra supports automatic data expiration (TTL) and uses tombstones to mark deletions, which can impact performance if not managed.

**Key Concepts:**
- TTL: time-to-live for automatic expiration
- Tombstones: markers for deleted data
- Compaction: cleans up tombstones

**Example:**
```sql
INSERT INTO sessions_by_user (user_id, session_id) VALUES (...) USING TTL 3600;
DELETE FROM sessions_by_user WHERE user_id = ... AND session_id = ...;
```

**Self-Check:**
- What is TTL? How does it work in Cassandra?
- What are tombstones? Why can they be a problem?
- How does compaction interact with tombstones?

**Lab:** 06_ttl_tombstones.cql

---

### 7. Aggregation, Filtering, and Counters
Cassandra has limited support for aggregation and filtering. Counters are supported but have caveats.

**Key Concepts:**
- Aggregation: only safe within a partition
- ALLOW FILTERING: can cause full table scans
- Counters: distributed, but with limitations

**Example:**
```sql
SELECT COUNT(*) FROM table WHERE partition_key = ...;
UPDATE page_views SET count = count + 1 WHERE url = ...;
```

**Self-Check:**
- Why is aggregation limited in Cassandra?
- What is the danger of using ALLOW FILTERING?
- How do counters work, and what are their caveats?

**Lab:** 07_aggregation_filtering.cql

---

### 8. Advanced Topics
Cassandra supports advanced features for large-scale, secure, and reliable deployments.

**Key Concepts:**
- Data distribution, hot partitions, anti-patterns
- Multi-DC replication, network topology
- Security: authentication, authorization
- Monitoring and repair

**Example:**
```sql
CREATE KEYSPACE demo_multi_dc WITH replication = {'class':'NetworkTopologyStrategy', 'dc1':2, 'dc2':2};
CREATE ROLE app_user WITH PASSWORD = 'replace_me' AND LOGIN = true;
GRANT SELECT ON keyspace_name.table_name TO app_user;
-- Use nodetool status, nodetool repair for monitoring and repair
```

**Self-Check:**
- What is a hot partition, and how do you avoid it?
- How does multi-DC replication work?
- What are some security features in Cassandra?
- How do you monitor and repair a Cassandra cluster?

**Labs:** 09_multi_dc_replication.cql, 10_security_basics.cql, 11_monitoring_and_repair.cql

---

This tutorial covers all major Cassandra concepts from basics to advanced, with explanations, examples, self-check questions, and mapped hands-on labs for each topic.
