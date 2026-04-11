# NoSQL & Cassandra

Cassandra is a distributed NoSQL database designed for high availability and scalability. This chapter introduces NoSQL concepts and explains why Cassandra is fundamentally different from traditional relational databases.

## Definitions & Core Concepts

### NoSQL Databases
**Definition**: NoSQL (Not Only SQL) databases are non-relational data stores designed to handle large volumes of distributed, unstructured data with flexible schemas.

**What it means**: Unlike relational databases that require:
- Fixed schema (tables with defined columns)
- ACID transactions across tables
- Complex joins
- Vertical scaling (bigger servers)

NoSQL databases offer:
- **Flexible/dynamic schema** - add columns without schema migration
- **Horizontal scaling** - add more servers, not bigger ones
- **High availability** - data replicated across multiple nodes
- **Eventual consistency** - data may be temporarily inconsistent across replicas
- **No joins** - data is denormalized and duplicated for access patterns

### Types of NoSQL Databases
1. **Key-Value** (Redis, Memcached): Simple key→value lookups, very fast
2. **Document** (MongoDB): JSON documents, flexible structure
3. **Column-Family** (Cassandra, HBase): Optimized for wide rows and time-series
4. **Graph** (Neo4j): Relationships and connections, optimized for traversal
5. **Search** (Elasticsearch): Full-text search and analytics

### Cassandra: Column-Family NoSQL
**Definition**: Cassandra is a distributed column-family NoSQL database that stores data in wide, sparse rows across a cluster of machines.

**What it means in practice**:
- **Distributed**: Data is spread across multiple nodes in a cluster
- **Decentralized**: No single point of failure; all nodes are equal
- **Column-Family**: Data organized in "tables" with many columns per row
- **Wide rows**: A single partition can have millions of columns
- **Sparse**: Not all rows need the same columns
- **Optimized for writes**: Data is immediately written to disk (LSM tree)

### Why Choose Cassandra Over Relational Databases?

| Aspect | Relational DB | Cassandra |
|--------|---------------|-----------|
| **Scale** | Vertical (bigger servers) | Horizontal (more nodes) |
| **Consistency** | Strong (ACID) | Eventual (tunable) |
| **Joins** | Efficient | Not supported |
| **Schema** | Fixed, rigid | Flexible, dynamic |
| **Write Throughput** | Moderate | Very high |
| **Real-time Analytics** | Yes | Limited |
| **Availability** | Can be compromised | Always available |

---

## The CAP Theorem

The CAP Theorem states that a distributed system can guarantee **at most two** of the following three properties:

### Consistency (C)
**Definition**: Every read returns the most recent write.

**Example**: In a bank, you withdraw $100, immediately check your balance, and see the updated amount. No stale data.

**In Cassandra**: Not guaranteed by default. With eventual consistency, your balance might show old data briefly.

### Availability (A)
**Definition**: System remains operational and responsive, even if some nodes fail.

**Example**: Your banking app works even if one or two data centers go down. You can still log in, check balance, withdraw money.

**In Cassandra**: ✅ Prioritized. Always responsive, never goes down.

### Partition Tolerance (P)
**Definition**: System continues operating despite network partitions (failures) between nodes.

**Example**: If a network cable breaks between two data centers, the system still functions (though possibly with inconsistent data).

**In Cassandra**: ✅ Required. Cassandra is designed for this.

### Cassandra's Choice: AP (Availability + Partition Tolerance)
Cassandra prioritizes **Availability** and **Partition Tolerance**, accepting **eventual consistency**:
- **Write succeeds** on one replica, propagated to others asynchronously
- **Read might be stale** briefly until replication completes
- **Tunable**: You can adjust consistency per query (trade-off: more replicas = higher latency)

---

## Why Cassandra is NOT a Drop-In Replacement for SQL Databases

### Key Differences

**1. No Joins**
```sql
-- SQL: Easy to join
SELECT u.name, o.order_date 
FROM users u 
JOIN orders o ON u.id = o.user_id;

-- Cassandra: Must denormalize data
-- Create orders table with user_name already stored
SELECT user_name, order_date FROM orders WHERE user_id = '123';
```

**2. No Multi-Row Transactions**
```sql
-- SQL: Atomic across tables
BEGIN;
  UPDATE accounts SET balance = balance - 100 WHERE id = 'acct1';
  UPDATE accounts SET balance = balance + 100 WHERE id = 'acct2';
COMMIT; -- All or nothing

-- Cassandra: Must handle each row separately
UPDATE accounts SET balance = balance - 100 WHERE account_id = 'acct1';
UPDATE accounts SET balance = balance + 100 WHERE account_id = 'acct2';
-- If second write fails, first has already succeeded
```

**3. Query-First Design, Not Normalization**
```sql
-- SQL: Single denormalized view handles all queries
SELECT * FROM users WHERE email = '...';
SELECT * FROM users WHERE phone = '...';
-- DB engine optimizes using indexes

-- Cassandra: Must create separate tables for each access pattern
CREATE TABLE users_by_email (email TEXT PRIMARY KEY, ...);
CREATE TABLE users_by_phone (phone TEXT PRIMARY KEY, ...);
-- Must manually keep both in sync
```

**4. Limited Ad-Hoc Querying**
```sql
-- SQL: Can query any column combination
SELECT * FROM orders WHERE price > 100 AND status = 'pending';

-- Cassandra: Must design table for exact queries
-- This query pattern wasn't designed? Full table scan → SLOW
SELECT * FROM orders WHERE price > 100 ALLOW FILTERING;
```

---

## When to Use Cassandra

### ✅ Good Use Cases
- **High-volume writes**: Millions of events per second (logs, metrics, IoT)
- **Time-series data**: Sensor data, stock prices, activity streams
- **Massive scale**: Terabytes to petabytes of data
- **High availability**: Banking, healthcare, real-time systems
- **Read-heavy, predictable patterns**: Content serving, session storage
- **Globally distributed**: Multi-region replication, local reads
- **Immutable/append-only**: Event stores, audit logs

### ❌ Not Suitable For
- **Complex reporting**: Ad-hoc queries, analytics (use data warehouse instead)
- **Small datasets**: Under 1TB, relational databases are simpler and cheaper
- **Complex transactions**: Multi-row ACID required (use PostgreSQL)
- **Frequent schema changes**: Cassandra schema migrations are slow
- **Transactional consistency critical**: Financial transactions need ACID (use relational DB)
- **Real-time aggregation**: Counting, summing across table (process offline)

---

## Real-World Examples

### Example 1: Netflix Activity Tracking
Netflix uses Cassandra to store billions of user activity events:
```
User watches a movie → Event written to multiple data centers → 
Distributed across 1000+ nodes → Replicated 3x → Always available
```

### Example 2: Uber Location Data
Uber tracks driver and passenger locations in real-time:
```
Driver location updates → Written to Cassandra → 
Geo-partitioned → Fast reads for nearby drivers → 
High write throughput (millions/second) → Fault-tolerant
```

### Example 3: What NOT to do with Cassandra
Trying to use Cassandra for a traditional accounting system:
```
❌ WRONG: Cassandra for banking with ACID requirements
   - Transactions across accounts aren't atomic
   - Eventual consistency causes problems
   - Better: PostgreSQL with proper backups

✅ RIGHT: Cassandra for transaction audit log
   - Immutable log of all transactions
   - Always available for reads
   - Perfect for Cassandra
```

---

## Example Diagram
<div class="mermaid">
graph TD
  A["CAP Theorem"] --> B["Choose 2 of 3"]
  B --> C["Consistency"]
  B --> D["Availability"]
  B --> E["Partition<br/>Tolerance"]
  
  F["Cassandra"] --> D
  F --> E
  F -.->|"Sacrifices"| C
  
  G["Database Choice"] --> H["SQL<br/>Relational"]
  G --> I["Cassandra<br/>Distributed"]
  G --> J["Hybrid<br/>Best of Both"]
  
  H -->|"Small data,<br/>ACID"| H
  I -->|"Big data,<br/>HA"| I
  J -->|"SQL + Cache<br/>+ Cassandra"| J
</div>

---

## Summary
- **NoSQL databases** prioritize scalability, availability, and performance over strict consistency.
- **Cassandra** is a distributed, decentralized, column-family database designed for high write throughput and fault tolerance.
- **CAP Theorem**: Cassandra chooses **Availability** and **Partition Tolerance**, accepting **eventual consistency**.
- **Not a replacement for SQL**: Requires query-first denormalized design; no joins or multi-row transactions.
- **Best for**: High-volume writes, time-series data, global distribution, always-on availability.
- **Not for**: Complex transactions, small datasets, ad-hoc analytics, real-time aggregations.
