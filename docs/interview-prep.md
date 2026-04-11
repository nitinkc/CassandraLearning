# Cassandra Interview Prep Guide (Q&A)

This guide provides concise, high-yield Q&A for quick revision. For deeper reading, see the referenced theory topics.

---

## 1. NoSQL and Cassandra Basics
**Q: What is NoSQL?**  
A: Non-relational, schema-less databases designed for distributed, scalable workloads. [Read more](theory/01-nosql-and-cassandra.md)

**Q: How does Cassandra differ from RDBMS?**  
A: Decentralized, flexible schema, optimized for high write throughput and horizontal scaling. No joins or multi-row transactions. [Read more](theory/01-nosql-and-cassandra.md)

**Q: What is the CAP theorem?**  
A: Distributed systems can only guarantee two of Consistency, Availability, and Partition tolerance. Cassandra is AP with tunable consistency. [Read more](theory/01-nosql-and-cassandra.md)

---

## 2. Core Cassandra Concepts
**Q: What is a partition key?**  
A: Determines data distribution across nodes. Good choice ensures even distribution and avoids hot spots. [Read more](theory/02-core-concepts.md)

**Q: What are clustering columns?**  
A: Define row order within a partition, enabling efficient range queries. [Read more](theory/02-core-concepts.md)

**Q: What is replication factor?**  
A: Number of data copies per data center. [Read more](theory/02-core-concepts.md)

**Q: What are consistency levels?**  
A: Control how many replicas must acknowledge a read/write. [Read more](theory/02-core-concepts.md)

---

## 3. Data Modeling and Querying
**Q: Why query-first modeling?**  
A: Tables are designed for specific queries to ensure fast, predictable reads. [Read more](theory/03-data-modeling.md)

**Q: When do you denormalize?**  
A: To support multiple access patterns efficiently, create separate tables for each query. [Read more](theory/03-data-modeling.md)

**Q: What is the ALLOW FILTERING anti-pattern?**  
A: Can cause full table scans and poor performance. [Read more](theory/03-data-modeling.md)

---

## 4. Indexes and Materialized Views
**Q: When use a secondary index?**  
A: Only for low-cardinality columns and small partitions. [Read more](theory/04-indexes-and-mv.md)

**Q: What are materialized views?**  
A: Denormalized copies for different query patterns, but can lag or become inconsistent. [Read more](theory/04-indexes-and-mv.md)

---

## 5. Consistency, LWT, and Batching
**Q: What is a lightweight transaction (LWT)?**  
A: Paxos-based, provides linearizable consistency for conditional updates. Slower than normal writes. [Read more](theory/05-consistency-lwt-batch.md)

**Q: When use batches?**  
A: For atomic multi-table writes. Avoid large batches. [Read more](theory/05-consistency-lwt-batch.md)

---

## 6. TTL, Tombstones, and Deletes
**Q: What is TTL?**  
A: Automatically expires data after a set period. [Read more](theory/06-ttl-tombstones.md)

**Q: What are tombstones?**  
A: Markers for deleted/expired data; too many degrade performance. [Read more](theory/06-ttl-tombstones.md)

---

## 7. Aggregation, Filtering, and Counters
**Q: Why is aggregation limited?**  
A: Only efficient within a partition; cluster-wide requires a full scan. [Read more](theory/07-aggregation-counters.md)

**Q: How do counters work?**  
A: Distributed, eventually consistent, can be inaccurate under contention. [Read more](theory/07-aggregation-counters.md)

---

## 8. Advanced Topics
**Q: What is a hot partition?**  
A: Receives disproportionate traffic; avoid with high-cardinality, well-distributed keys. [Read more](theory/08-advanced.md)

**Q: How does multi-DC replication work?**  
A: Data is replicated to multiple data centers using NetworkTopologyStrategy. [Read more](theory/08-advanced.md)

**Q: How do you monitor and repair a cluster?**  
A: Use nodetool, logs, and monitoring tools. [Read more](theory/08-advanced.md)

---

For deeper explanations, diagrams, and examples, see the linked theory topics.
