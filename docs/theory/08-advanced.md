# Advanced Topics

Advanced Cassandra features for large-scale, secure, and reliable deployments. These topics are essential for production-grade systems.

## Definitions & Core Concepts

### Hot Partitions
**Definition**: A hot partition is a partition (or set of partitions) that receives a disproportionate amount of traffic compared to other partitions in the same table.

**What it means**:
- One node becomes a bottleneck while others are idle
- Limits throughput to hot partition's node capacity
- Causes latency spikes and timeouts
- **Most common Cassandra performance issue**
- Result of poor partition key design or skewed data distribution

**Example of Hot Partition**:
```cql
CREATE TABLE user_activity (
  user_id UUID,
  activity_date DATE,
  action TEXT,
  PRIMARY KEY (user_id, activity_date, action)
);

-- Celebrity user: 1M actions per second
-- Regular user: 100 actions per second
-- Partition key = user_id
// Celebrity's partition is on Node1
// Node1 handles 10x more traffic than Node2, Node3

// Result: Node1 CPU/network saturated
// Celebrity actions slow, timeouts
// Other nodes idle
```

**Identifying Hot Partitions**:
- Monitor node CPU and network traffic (should be balanced)
- Use nodetool or JMX metrics
- Watch for timeouts on specific queries
- Query patterns show specific partition keys taking most traffic

### Preventing Hot Partitions

**Strategy 1: Composite Partition Key (Salting)**
```cql
-- Distribute hot data across multiple partitions
CREATE TABLE celebrity_activity (
  user_id UUID,
  shard INT,  -- NEW: 0-9
  activity_date DATE,
  action TEXT,
  PRIMARY KEY ((user_id, shard), activity_date, action)
);

-- When inserting, randomly pick a shard (0-9)
INSERT INTO celebrity_activity (user_id, shard, activity_date, action)
VALUES (celebrity_uuid, random() % 10, today(), 'liked_video');

-- Traffic now spreads across 10 partitions instead of 1
// Single partition: 100K writes/sec
// Spread across 10: ~10K writes/sec per partition
```

**Strategy 2: Time-Bucket Distribution**
```cql
-- Already using in time-series
CREATE TABLE metrics (
  sensor_id UUID,
  date_bucket DATE,
  timestamp TIMESTAMP,
  value DOUBLE,
  PRIMARY KEY ((sensor_id, date_bucket), timestamp)
);

// If sensor sends constant stream of data:
// Partition rotates daily (sensor_id, 2024-01-01) → (sensor_id, 2024-01-02)
// Load spreads over time buckets
```

**Strategy 3: Better Partition Key**
```cql
-- BAD: Partition by low-cardinality field
CREATE TABLE status_tasks (
  status TEXT,  -- Only "pending", "done", "failed"
  task_id UUID,
  PRIMARY KEY (status)
);
// All "pending" tasks → one partition → hot spot

-- BETTER: Partition by high-cardinality field
CREATE TABLE tasks (
  task_id UUID,  -- Millions of unique values
  status TEXT,
  PRIMARY KEY (task_id)
);
// Each task is own partition → distributed evenly
```

---

## Multi-Datacenter Replication

### Definition
**Definition**: Multi-DC replication is maintaining copies of data across geographically distributed data centers for disaster recovery, local reads, and high availability.

**What it means**:
- Data replicated across multiple DCs automatically
- Can read from nearest DC (low latency)
- Can write to nearest DC (local quorum)
- Survive entire DC failures
- Data consistency eventually across DCs

### NetworkTopologyStrategy

**Definition**: A replication strategy that controls how many replicas in each data center.

**Example**:
```cql
CREATE KEYSPACE app_data WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC_US_EAST': 3,      -- 3 replicas in US East
  'DC_EU_WEST': 3,      -- 3 replicas in EU West
  'DC_ASIA': 2          -- 2 replicas in Asia
};

-- Data replicated automatically:
-- Write to DC_US_EAST → replicated to DC_EU_WEST → replicated to DC_ASIA
-- Takes time (milliseconds to seconds depending on network)
```

### Multi-DC Query Patterns

**Local Quorum Writes**
```cql
-- Write to nearest DC first (fast)
INSERT INTO users (user_id, name) 
VALUES (user123, 'Alice')
USING CONSISTENCY LOCAL_QUORUM;

// What happens:
// 1. Coordinator in nearest DC waits for quorum in that DC only
// 2. Returns success immediately (no remote DC latency)
// 3. Remote DCs get data asynchronously
```

**Local Quorum Reads**
```cql
SELECT * FROM users WHERE user_id = 'user123'
USING CONSISTENCY LOCAL_QUORUM;

// Reads from replicas in local DC only
// Fast because no remote DC latency
// Might be slightly stale (remote DC writes pending)
```

**Global Consistency (Across DCs)**
```cql
-- Ensure all DCs have data
INSERT INTO critical_data (id, value)
VALUES (data123, 'important')
USING CONSISTENCY QUORUM;  -- Global QUORUM across all DCs

// Much slower, but guarantees consistency across all regions
// Use only for critical data
```

### Multi-DC Challenges

**Network Latency**:
```
DC_WEST (US): Coordinator at DC_WEST, replicate to:
  - DC_EAST (US): 20ms away
  - DC_EU: 100ms away
  - DC_ASIA: 200ms away

Write with QUORUM: Wait for 2 of 3 DCs = ~100-200ms latency
Write with LOCAL_QUORUM: Wait for local replicas = ~5-20ms latency
```

**Conflict Resolution**:
```
Scenario: Concurrent writes from different DCs

DC_WEST: Update user name to 'Alice' at T=1000
DC_EAST: Update user name to 'Bob' at T=1001

Cassandra uses timestamp tiebreak:
- T=1001 > T=1000
- 'Bob' wins
- Both DCs eventually converge to 'Bob'

But: Race conditions possible, last-write-wins may not be correct
```

---

## Security

### Authentication
**Definition**: Mechanism to verify user identity before allowing access.

**Example**:
```
Cassandra native authentication:
- Default: No auth (disabled)
- Enable: require username/password
- Connect: cqlsh -u cassandra -p cassandra
```

### Authorization
**Definition**: Mechanism to control what authenticated users can do (permissions).

**Example**:
```cql
-- Create user
CREATE USER alice WITH PASSWORD 'secret123';

-- Grant permissions
GRANT SELECT ON app_data.users TO alice;
GRANT MODIFY ON app_data.users TO alice;
GRANT ALL ON app_data TO admin_user;

-- Alice can SELECT/INSERT on app_data.users
// Alice cannot DELETE
// Alice cannot access other keyspaces
```

### Encryption

**Encryption in Transit**
```
Client → Cassandra: SSL/TLS encryption
  Prevents eavesdropping on network
  Default: Disabled (enable for security)
  Performance: ~5-10% overhead
```

**Encryption at Rest**
```
Data stored on disk: encrypted
  Requires key management (external KMS)
  Protects against stolen disks
  Default: Disabled
  Performance: ~10-20% overhead
```

### Best Practices
✅ Enable authentication in production
✅ Use strong passwords (20+ chars, mixed case/numbers/symbols)
✅ Enable encryption in transit for sensitive data
✅ Enable encryption at rest for compliance
✅ Regular security updates and patches
✅ Monitor audit logs
✅ Least privilege: grant minimal permissions

---

## Monitoring & Repair

### nodetool
**Definition**: A command-line utility for monitoring and managing Cassandra clusters.

**Common Commands**:
```bash
# Check node status
nodetool status

# Check data repair status
nodetool repair keyspace_name

# View table stats
nodetool cfstats keyspace_name.table_name

# Flush memtable to disk
nodetool flush

# Check compaction progress
nodetool compactionstats

# View GC info
nodetool gcstats

# Check ring/token distribution
nodetool ring
```

### Metrics to Monitor

| Metric | What it tells | Alert threshold |
|--------|--------------|-----------------|
| **Read latency** | Query response time | > 100ms |
| **Write latency** | Insert response time | > 50ms |
| **GC pause time** | JVM garbage collection | > 1s |
| **Compaction pending** | SSTable merging queue | > 10 SSTables |
| **Tombstone ratio** | Tombstone count / total rows | > 50% |
| **Disk usage** | Data + overhead | > 80% capacity |
| **CPU usage** | Node CPU load | > 80% |
| **Network I/O** | Replication traffic | Imbalanced across nodes |

### Anti-Entropy Repair

**Definition**: Repair is a background process that synchronizes replicas and fixes data inconsistencies.

**How repair works**:
```
1. Merkle trees: Compare partition keys between replicas
2. Identify differences: Mismatches in data
3. Stream repairs: Send missing data to replicas
4. Verify: Confirm all replicas match

Use case: After node failure/recovery, sync all replicas
Triggers: Can be manual (nodetool repair) or auto-schedule
Frequency: Weekly or monthly (before/after maintenance)
```

**Types of Repair**:

| Type | Scope | Time | Use Case |
|------|-------|------|----------|
| **Full** | All partitions | 1-2 hours | After node failure |
| **Incremental** | Since last repair | 10-30 min | Weekly routine |
| **Parallel** | Multi-threaded | Faster | Multi-core systems |

---

## Performance Tuning

### Key Tuning Parameters

**JVM Heap Size**
```bash
# Default: 1/4 of system RAM
# Cassandra typically: 8GB - 16GB

# Set in cassandra-env.sh:
#MAX_HEAP_SIZE="8G"
#HEAP_NEWSIZE="2G"

# Rule of thumb:
// < 100GB data: 4-8GB heap
// 100GB - 1TB: 8-16GB heap
// > 1TB: 16-32GB heap
// (Monitor GC pressure)
```

**Memtable Size**
```
# Controls in-memory write buffer
# Default: 1/4 of heap (if 8GB heap → 2GB memtable)

# Larger memtable:
// ✓ Fewer disk writes
// ✓ Better write throughput
// ✗ Longer GC pauses

# Smaller memtable:
// ✓ Frequent disk flushes
// ✓ Lower latency spikes
// ✗ More SSTable files to compact
```

**Bloom Filter Size**
```
# Speeds up read lookups ("does row exist?")
# Smaller = faster checks, more false positives (rescan)
# Larger = slower checks, fewer false positives

# Tune based on workload:
// Many random reads: larger bloom filter
// Sequential reads: smaller bloom filter
```

---

## Common Issues & Solutions

### Issue 1: High Read Latency

**Symptoms**:
- Queries taking 500ms+ (should be 10-50ms)
- Intermittent slowness (GC spikes?)

**Causes**:
1. Hot partitions (uneven data distribution)
2. High tombstone ratio (many deleted rows)
3. Bloom filter misses → disk seeks
4. GC pauses (JVM garbage collection)

**Solutions**:
```
1. Shard hot partitions (add composite key)
2. Reduce gc_grace_seconds or compact more aggressively
3. Tune bloom filter, cache settings
4. Increase heap, reduce GC pauses
```

### Issue 2: Out of Memory / High GC

**Symptoms**:
- "GC overhead limit exceeded"
- Frequent Full GC pauses (5-30 seconds)
- Node becomes unresponsive during GC

**Causes**:
1. Heap too small for workload
2. Bloom filters/caches too large
3. Memory leaks in application
4. Compaction building large SSTables

**Solutions**:
```
1. Increase heap size (8GB → 16GB)
2. Reduce cache sizes
3. Split compaction into smaller tasks
4. Monitor and profile memory usage
```

### Issue 3: Repair Timeouts

**Symptoms**:
- `nodetool repair` hangs or fails
- Repairs take hours for small clusters

**Causes**:
1. Network issues between nodes
2. Disk I/O slow (repair + compaction = loads disk)
3. Cassandra version bugs

**Solutions**:
```
1. Run repair during low-traffic window
2. Use -pr (primary replica) flag: only repair local replicas
3. Increase timeout settings
4. Consider incremental repair (faster)
```

---

## Example Diagram
<div class="mermaid">
graph TD;
  A["Cluster Design"] --> B["Prevent Hot<br/>Partitions"]
  B --> C["Composite<br/>Partition Key"]
  B --> D["Time<br/>Buckets"]
  B --> E["Better PK<br/>Selection"]
  
  A --> F["Multi-DC<br/>Setup"]
  F --> G["NetworkTopologyStrategy"]
  G --> H["Local Quorum<br/>Writes"]
  G --> I["Global Quorum<br/>Critical Data"]
  
  A --> J["Security<br/>& Monitoring"]
  J --> K["Auth +<br/>Encryption"]
  J --> L["nodetool<br/>repair"]
  J --> M["Metrics<br/>& Alerts"]
  
  N["Performance"] --> O["Tune JVM<br/>Heap"]
  N --> P["Monitor<br/>Latency"]
  N --> Q["Compaction<br/>Strategy"]
</div>

---

## Production Checklist

Before deploying to production:

- [ ] Capacity planning: Estimate data growth, replication factor, RF
- [ ] Consistency levels: Chosen based on durability/latency requirements
- [ ] Backup strategy: Regular backups, test restoration
- [ ] Monitoring: Set up alerts for latency, GC, disk, tombstones
- [ ] Authentication: Enabled, strong passwords
- [ ] Encryption: In transit for sensitive data
- [ ] Repair schedule: Weekly or monthly incremental repair
- [ ] Compaction strategy: Selected based on workload (size-tiered, leveled, etc.)
- [ ] TTL policies: Defined for temporary data
- [ ] Testing: Load testing, failure scenario testing
- [ ] Documentation: Runbooks, emergency procedures
- [ ] Training: Team familiar with nodetool, troubleshooting

---

## Summary
- **Hot Partitions**: Design composite partition keys or use sharding; monitor node balance.
- **Multi-DC**: Use NetworkTopologyStrategy and LOCAL_QUORUM for fast local operations.
- **Security**: Enable auth, enforce strong passwords, encrypt transit and rest.
- **Monitoring**: Track latency, GC, compaction, tombstones; use nodetool for cluster health.
- **Repair**: Run weekly/monthly anti-entropy repair to maintain data consistency.
- **Tuning**: Adjust heap, memtable, cache settings based on workload and monitoring data.
