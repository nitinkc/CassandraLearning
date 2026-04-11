# Cassandra Interview Q&A (with Answers)

## 1. What is NoSQL, and how does Cassandra fit in?
NoSQL databases are non-relational and designed for distributed, scalable workloads. Cassandra is a column-family NoSQL database optimized for high availability and horizontal scaling.

## 2. What is a partition key, and why is it important?
The partition key determines how data is distributed across nodes. A good partition key ensures even data distribution and avoids hot spots.

## 3. Why does Cassandra use query-first data modeling?
Cassandra tables are designed for specific queries to ensure fast, predictable reads. There are no joins; denormalization is common.

## 4. What is a secondary index, and when should you use it?
A secondary index allows queries on non-primary key columns. Use only for low-cardinality columns and small partitions; avoid for high-cardinality or large tables.

## 5. What is a lightweight transaction (LWT)?
LWTs use the Paxos protocol to provide linearizable consistency for conditional updates (e.g., IF NOT EXISTS). They are slower than normal writes.

## 6. What is TTL, and what are tombstones?
TTL (time-to-live) automatically expires data after a set period. Tombstones are markers for deleted or expired data; too many can degrade performance.

## 7. Why is aggregation limited in Cassandra?
Aggregation (e.g., COUNT(*)) is only efficient within a partition. Cluster-wide aggregation requires a full scan and is not recommended.

## 8. How does multi-DC replication work?
Data is replicated to multiple data centers using NetworkTopologyStrategy, with separate replication factors per DC.

## 9. How do you monitor and repair a Cassandra cluster?
Use nodetool (status, repair, cleanup), logs, and monitoring tools (e.g., Prometheus, Grafana) to monitor and maintain cluster health.
# Cassandra Theory Guide (Q&A)

## 1. NoSQL and Cassandra Basics
**Q: What is NoSQL?**  
A: NoSQL databases are non-relational, schema-less, and designed for distributed, scalable workloads. They include key-value, document, column-family (like Cassandra), and graph databases.

**Q: How does Cassandra differ from relational databases?**  
A: Cassandra is decentralized, uses a flexible schema, and is optimized for high write throughput and horizontal scaling. It does not support joins or multi-row transactions like RDBMS.

**Q: What is the CAP theorem, and where does Cassandra fit?**  
A: The CAP theorem states that a distributed system can only guarantee two of Consistency, Availability, and Partition tolerance. Cassandra prioritizes Availability and Partition tolerance (AP), with tunable consistency.

## 2. Core Cassandra Concepts
**Q: What is a cluster, node, and data center in Cassandra?**  
A: A cluster is a group of nodes (servers) that store data. Nodes are grouped into data centers for replication and fault tolerance.

**Q: What is a partition key, and why is it critical?**  
A: The partition key determines how data is distributed across nodes. Good partition key choice ensures even data distribution and avoids hot spots.

**Q: What are clustering columns?**  
A: Clustering columns define the order of rows within a partition, enabling efficient range queries and sorting.

**Q: What is replication factor?**  
A: Replication factor (RF) is the number of copies of data stored in the cluster, per data center.

**Q: What are consistency levels?**  
A: Consistency levels (e.g., ONE, QUORUM, ALL) control how many replicas must acknowledge a read or write for it to succeed.

**Q: What causes hot partitions?**  
A: Poor partition key choice (e.g., low cardinality, monotonically increasing values) can cause some nodes to receive disproportionate traffic.

## 3. Data Modeling and Querying
**Q: Why is data modeled by query in Cassandra?**  
A: Cassandra tables are designed for specific queries to ensure fast, predictable reads. There are no joins; denormalization is common.

**Q: When do you denormalize and duplicate data?**  
A: When you need to support multiple access patterns efficiently, you create separate tables for each query, duplicating data as needed.

**Q: How do you design tables for time-series data?**  
A: Use a compound primary key with a time bucket (e.g., day, month) as part of the partition key to avoid unbounded partitions.

**Q: What is the anti-pattern of using ALLOW FILTERING?**  
A: ALLOW FILTERING enables queries not supported by the table’s primary key, but can cause full table scans and poor performance.

**Q: How do you handle one-to-many and many-to-many relationships?**  
A: Use wide rows (clustering columns) for one-to-many, and create join tables for many-to-many, each designed for a specific query.

## 4. Indexes and Materialized Views
**Q: When should you use a secondary index?**  
A: Use only for low-cardinality columns and small partitions. Avoid for high-cardinality or large tables.

**Q: What are materialized views?**  
A: Materialized views automatically maintain a denormalized copy of data for a different query pattern. They can lag or become inconsistent, so explicit dual-writes are often preferred.

## 5. Consistency, LWT, and Batching
**Q: What is a lightweight transaction (LWT)?**  
A: LWTs use the Paxos protocol to provide linearizable consistency for conditional updates (e.g., IF NOT EXISTS). They are slower than normal writes.

**Q: When should you use batches?**  
A: Use logged batches for atomic multi-table writes. Avoid large batches; they can cause performance issues.

## 6. TTL, Tombstones, and Deletes
**Q: What is TTL?**  
A: TTL (time-to-live) automatically expires data after a set period.

**Q: What are tombstones?**  
A: Tombstones are markers for deleted or expired data. Excessive tombstones can degrade read and compaction performance.

## 7. Aggregation, Filtering, and Counters
**Q: Why is aggregation limited in Cassandra?**  
A: Aggregation (e.g., COUNT(*)) is only efficient within a partition. Cluster-wide aggregation requires a full scan.

**Q: What is the danger of using ALLOW FILTERING?**  
A: It can trigger full table scans, leading to unpredictable performance.

**Q: How do counters work, and what are their caveats?**  
A: Counters are distributed and eventually consistent. They can be inaccurate if used with batches or under heavy contention.

## 8. Advanced Topics
**Q: What is a hot partition, and how do you avoid it?**  
A: A hot partition receives disproportionate traffic. Avoid by choosing high-cardinality, well-distributed partition keys.

**Q: How does multi-DC replication work?**  
A: Data is replicated to multiple data centers using NetworkTopologyStrategy, with separate RF per DC.

**Q: What are some security features in Cassandra?**  
A: Authentication, authorization (roles/permissions), and optional encryption (SSL/TLS).

**Q: How do you monitor and repair a Cassandra cluster?**  
A: Use nodetool (status, repair, cleanup), logs, and monitoring tools (e.g., Prometheus, Grafana).

