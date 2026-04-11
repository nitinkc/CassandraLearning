# Cassandra Labs Overview

This page summarizes each hands-on lab, what it demonstrates, and which theory topic(s) it reinforces.

| Lab | Description | Reinforces Theory |
|-----|-------------|-------------------|
| 01_keyspace_basics.cql | Keyspace creation, SimpleStrategy, basic table | [NoSQL & Cassandra Basics](theory/01-nosql-and-cassandra.md), [Core Concepts](theory/02-core-concepts.md) |
| 02_partitioning_clustering.cql | Partition keys, clustering columns, bounding partitions | [Core Concepts](theory/02-core-concepts.md), [Data Modeling](theory/03-data-modeling.md) |
| 03_modeling_by_query.cql | Query-driven modeling, denormalization, lookup tables | [Data Modeling](theory/03-data-modeling.md) |
| 04_indexes_and_mv.cql | Secondary indexes, materialized views, trade-offs | [Indexes & MVs](theory/04-indexes-and-mv.md) |
| 05_consistency_lwt_batch.cql | Consistency levels, lightweight transactions, batches | [Consistency, LWT, Batching](theory/05-consistency-lwt-batch.md) |
| 06_ttl_tombstones.cql | TTL, tombstones, deletes, compaction | [TTL & Tombstones](theory/06-ttl-tombstones.md) |
| 07_aggregation_filtering.cql | Aggregation, ALLOW FILTERING, counters | [Aggregation & Counters](theory/07-aggregation-counters.md) |
| 08_relational_to_query_first.cql | Converting relational models to query-first Cassandra models | [Data Modeling](theory/03-data-modeling.md) |
| 09_multi_dc_replication.cql | NetworkTopologyStrategy, multi-DC setup | [Advanced Topics](theory/08-advanced.md) |
| 10_security_basics.cql | Authentication, roles, permissions | [Advanced Topics](theory/08-advanced.md) |
| 11_monitoring_and_repair.cql | nodetool, cluster health, repairs | [Advanced Topics](theory/08-advanced.md) |

For details and hands-on steps, see each lab file in the `labs/` directory.

