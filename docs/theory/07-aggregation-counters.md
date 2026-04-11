# Aggregation & Counters

Cassandra has limited support for aggregation and distributed counters. This chapter explores how these features work, their limitations, and best practices for using them effectively.

## Definitions & Core Concepts

### Aggregation
**Definition**: Aggregation is the process of combining multiple row values into a single computed result using functions like `SUM()`, `AVG()`, `COUNT()`, `MIN()`, and `MAX()`.

**What it means in Cassandra context**: Unlike traditional relational databases, Cassandra does not efficiently support aggregate queries across the entire table or large portions of data. This is because Cassandra is designed for fast, predictable queries on specific partitions, not for scanning large datasets.

**Why the limitation exists**: Cassandra's distributed nature and partition-based architecture mean that aggregation across partitions requires:
- Querying multiple nodes
- Aggregating results from all nodes
- Network overhead and latency
- Potential inconsistency due to eventual consistency model

### ALLOW FILTERING
**Definition**: `ALLOW FILTERING` is a CQL clause that permits queries to scan beyond the partition key and clustering columns, effectively enabling filtering on any column.

**What it means**: When you use `ALLOW FILTERING`, Cassandra will:
1. Retrieve rows matching the partition key
2. Load them into memory
3. Apply the filter condition to each row client-side
4. Return only matching rows

**The danger**: Without `ALLOW FILTERING`, Cassandra strictly enforces queries that leverage your table's primary key design. With it enabled, you bypass this safety mechanism, which can lead to:
- Full table scans (reading every partition)
- High memory consumption
- Timeouts and performance degradation
- Unexpected costs in production environments

### Counters
**Definition**: A counter is a special data type in Cassandra (`COUNTER`) designed for distributed increment/decrement operations. It's a 64-bit signed integer that can be safely incremented or decremented across multiple replicas.

**What it means**: Instead of reading a value, incrementing it, and writing it back (which loses concurrent increments), counters use a vector clock mechanism to track and merge increments from different replicas.

**How they work**:
- Each replica maintains a local counter value
- Increments are replicated to other nodes
- When nodes reconcile, they merge counters using vector logic
- Eventually, all replicas converge to the same value

**The catch**: Counters are:
- **Eventually consistent**: Not immediately accurate under high concurrency
- **Subject to contention**: Under heavy write load, accuracy degrades
- **Cannot be decremented below zero** (in some Cassandra versions)
- **Cannot be used with TTL** (time to live)
- **Cannot be part of the primary key**

---

## Key Points with Expanded Context

### Aggregation Efficiency
- **Within a partition**: ✅ Efficient - data is co-located on one or few nodes; minimal network overhead
- **Across partitions**: ❌ Inefficient - requires scanning multiple nodes; use materialized views or batch processing instead
- **Cluster-wide**: ❌ Very inefficient - full table scan; avoid at all costs in production

### ALLOW FILTERING Risks
- **Best for**: Small result sets (e.g., filtering 1000 rows to 10)
- **Worst for**: Large tables without restrictive partition keys
- **When to use**: Development, small datasets, or when you have a partition key that already narrows results significantly
- **When to avoid**: Production queries on large tables without partition key filtering

### Counters in Practice
- **Use cases**: Page view counts, visitor counters, activity tracking, statistics
- **Anti-patterns**: Financial transactions, exact inventory counts, anything requiring immediate consistency
- **Best practice**: Accept eventual consistency; use bounded contexts; don't rely on absolute accuracy

---

## Real-World Examples

### Aggregation Example
```cql
-- ✅ GOOD: Aggregate within a single partition
SELECT COUNT(*) FROM user_events 
WHERE user_id = '12345';

-- ❌ AVOID: Aggregate across many partitions
SELECT COUNT(*) FROM user_events;

-- ✅ ALTERNATIVE: Use materialized view or separate aggregate table
CREATE TABLE user_event_counts (
  user_id UUID PRIMARY KEY,
  event_count BIGINT
);
```

### ALLOW FILTERING Example
```cql
-- ✅ GOOD: Filtered by partition key, then clustering column
SELECT * FROM orders 
WHERE customer_id = 'cust_123' AND order_date > '2024-01-01'
ALLOW FILTERING;

-- ❌ BAD: Full table scan looking for emails
SELECT * FROM users 
WHERE email = 'john@example.com'
ALLOW FILTERING;
```

### Counter Example
```cql
-- Define a counter table
CREATE TABLE page_views (
  page_id UUID PRIMARY KEY,
  view_count COUNTER
);

-- Increment the counter
UPDATE page_views SET view_count = view_count + 1 
WHERE page_id = '550e8400-e29b-41d4-a716-446655440000';

-- Read the counter (might not be perfectly accurate under load)
SELECT view_count FROM page_views 
WHERE page_id = '550e8400-e29b-41d4-a716-446655440000';
```

---

## Patterns & Best Practices

### For Aggregation
1. **Denormalize**: Pre-compute and store aggregate values during writes
2. **Materialized Views**: Use MVs to maintain aggregated data automatically
3. **Batch Processing**: Run aggregate jobs offline using Spark or similar
4. **Partition-level**: If aggregation is necessary, limit to single partitions

### For ALLOW FILTERING
1. **Document usage**: Mark queries that use it for monitoring
2. **Test throughput**: Always test performance with production-scale data
3. **Add metrics**: Monitor how often these queries run and their latency
4. **Migrate over time**: Plan to refactor queries with better schema designs

### For Counters
1. **Accept approximation**: Design systems that tolerate eventual consistency
2. **Separate concerns**: Keep counters in separate tables from transactional data
3. **Monitor contention**: Watch for hot partitions with high counter traffic
4. **Batch updates**: Where possible, batch counter increments to reduce load

---

## Example Diagram
<div class="mermaid">
graph TD;
  A["Query Types"] -->|"Partition-only"| B["✅ Efficient<br/>Single Node"]
  A -->|"Multi-partition"| C["❌ Inefficient<br/>Multiple Nodes"]
  A -->|"Full table"| D["❌ Very Slow<br/>All Nodes"]
  
  E["ALLOW FILTERING"] -->|"Small result set"| F["⚠️ Acceptable"]
  E -->|"Large scan"| G["❌ Avoid"]
  
  H["Counters"] -->|"Increments"| I["Vector Clock<br/>Merge"]
  I -->|"Replication"| J["Eventually<br/>Consistent"]
</div>

---

## Summary
- **Aggregate only within partitions** when possible. For cross-partition aggregation, use denormalization, materialized views, or batch processing.
- **Use counters with care** and expect eventual consistency; they're not suitable for scenarios requiring strong consistency.
- **Avoid ALLOW FILTERING** on large tables. If you find yourself needing it frequently, redesign your schema to support your queries directly through the primary key.
- **Design your schema query-first**: Anticipate your aggregation needs upfront and model your data accordingly.
