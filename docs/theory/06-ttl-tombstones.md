# TTL & Tombstones

Cassandra supports automatic data expiration (TTL) and uses tombstones to mark deletions. Understanding these concepts is essential for managing data lifecycle and preventing performance degradation.

## Definitions & Core Concepts

### TTL (Time To Live)
**Definition**: TTL is a mechanism in Cassandra that automatically deletes data after a specified duration, without requiring explicit deletion commands.

**What it means**:
- Set when writing data: "Keep this for 3600 seconds, then delete"
- After TTL expires, data is effectively deleted
- No manual cleanup required
- Can be set per row, cell, or column

### How TTL Works

**Scenario: Session Data**
```cql
CREATE TABLE sessions (
  session_id UUID PRIMARY KEY,
  user_id UUID,
  token TEXT,
  created_at TIMESTAMP
);

-- Insert with TTL: expire after 1 hour (3600 seconds)
INSERT INTO sessions (session_id, user_id, token, created_at)
VALUES (sess123, user456, 'token_xyz', now())
USING TTL 3600;

-- Timeline:
// T=0 seconds: Data inserted, TTL countdown starts
// T=1799: Data still available
// T=3600: TTL expires
// T=3601: Data is marked for deletion (becomes tombstone)
// T=3601+gc_grace_seconds: Data is physically deleted
```

**TTL at Column Level**
```cql
INSERT INTO sessions (session_id, user_id, token)
VALUES (sess123, user456, 'token_xyz')
USING TTL 3600;

-- Only token expires after 3600 seconds
-- session_id and user_id stay (no TTL on their insert)
```

### Tombstones
**Definition**: A tombstone is a marker left behind when data is deleted or expires. It prevents reappearance of deleted data during replication.

**What it means**:
- When data is deleted, Cassandra doesn't immediately erase it
- Instead, writes a tombstone record (like a "deleted" marker)
- Tombstone prevents deleted data from reappearing due to eventual consistency
- Eventually, tombstones are removed during compaction

### Why Tombstones Are Needed

**The Problem Without Tombstones**:
```
Scenario: Eventual consistency with deletion

Node1: DELETE user 'alice'
       user 'alice' is deleted from Node1

Meanwhile:
Node2: Still has user 'alice' (hasn't received delete yet)
Node3: Still has user 'alice'

Later, replication repairs Node1:
Node2 replicates its copy to Node1
Node1: Oh! User 'alice' is back (reappeared!)

Result: Deleted data resurrects
```

**With Tombstones**:
```
Node1: DELETE user 'alice'
       → Writes tombstone: "user 'alice' was deleted at T=1000"

Node2: Still has user 'alice' (pre-deletion)
Node3: Still has user 'alice'

Later, replication:
Node2 replicates user 'alice' to Node1
Node1: This is from T=500, tombstone is from T=1000
       Tombstone wins (latest write)
       Data stays deleted

Result: Deletion is durable across replicas
```

---

## TTL in Practice

### Setting TTL

**Per-Write TTL**
```cql
-- Insert with 24-hour TTL
INSERT INTO user_temp_codes (user_id, code)
VALUES (user123, 'code_abc')
USING TTL 86400;

-- Update with TTL
UPDATE user_temp_codes
SET code = 'code_xyz'
WHERE user_id = user123
USING TTL 86400;
```

**Default TTL in Table**
```cql
-- Set default TTL for entire table
CREATE TABLE session_data (
  session_id UUID PRIMARY KEY,
  user_id UUID,
  data TEXT
) WITH default_time_to_live = 3600;

-- All writes default to 3600 second TTL (unless overridden)
INSERT INTO session_data ...;  -- Automatically gets 3600s TTL
INSERT INTO session_data USING TTL 7200 ...;  -- Override default
```

**No TTL (Live Forever)**
```cql
-- Explicitly set TTL to 0 (no expiration)
INSERT INTO users (user_id, name)
VALUES (user123, 'Alice')
USING TTL 0;

-- Can also unset TTL by writing with no USING clause:
INSERT INTO users (user_id, name)
VALUES (user123, 'Alice');
```

### TTL Use Cases

✅ **Good use cases**:
- **Sessions**: Expire user sessions after inactivity (24-48 hours)
- **Temporary tokens**: OTP codes, password reset links (5-30 minutes)
- **Cache-like data**: Non-critical data that can be regenerated
- **Time-limited offers**: Promotions valid for limited time
- **Audit logs**: Keep recent logs (1-2 years), auto-delete old ones
- **Device tokens**: Mobile push tokens expire/rotate

❌ **Avoid TTL for**:
- **Critical data**: User profiles, account info
- **Financial records**: Transactions, billing data
- **Legal/compliance**: Data with retention requirements

---

## Tombstones & Compaction

### The Tombstone Problem

**Scenario: High Delete Velocity**
```
Application: "Delete completed orders"
100,000 orders per day are marked as completed
Each deletion → writes a tombstone

After 30 days:
- 3 million tombstones in table
- Table size grows (tombstones take space)
- Read performance degrades (must scan tombstones)
- Compaction must process millions of tombstones
```

**Performance Impact**:
```
Query: SELECT * FROM orders WHERE customer_id = 'cust123'
Table: 1M rows, 500K tombstones

Cassandra:
1. Reads partition for cust123 (might be 10K rows)
2. Has to scan through tombstones to find actual data
3. Tombstone overhead = more disk IO, more memory, slower reads

Impact: Read latency increases as tombstone ratio increases
```

### gc_grace_seconds

**Definition**: `gc_grace_seconds` is the time window after which tombstones are eligible for deletion.

**What it means**:
- Default is 864000 seconds (10 days)
- After a tombstone is written, Cassandra waits gc_grace_seconds
- Then compaction can remove the tombstone
- If replica comes back online within gc_grace_seconds, it sees tombstone (deletion is consistent)
- If replica comes back after gc_grace_seconds, deleted data might reappear (resurrection)

**Example**:
```
T=0: Data deleted, tombstone written
T=0-86400 (10 days): Tombstone is protected, read repairs still work
T=86401: Tombstone eligible for removal during compaction
T=86401+: Tombstone might be deleted (storage reclaimed)

If Node1 went offline at T=0 and comes back at T=85000:
  → Sees tombstone, deletion is consistent ✓

If Node1 went offline at T=0 and comes back at T=90000:
  → Tombstone already deleted, sees original data (RESURRECTION!) ✗
```

### Compaction

**Definition**: Compaction is a background process that:
1. Merges multiple SSTable files
2. Removes tombstones older than gc_grace_seconds
3. Reclaims disk space
4. Improves read performance

**Types of Compaction**:

| Type | Merge | Tombstone Removal | Use Case |
|------|-------|-------------------|----------|
| **SizeTiered** | Smaller SSTables | Yes | Default, general purpose |
| **Leveled** | Keep levels balanced | Yes | Write-heavy, predictable |
| **TimeWindow** | By time window | Yes | Time-series data |

### Managing Tombstones

✅ **Best Practices**:

1. **Understand your delete pattern**
   ```cql
   -- If deleting >10% of data: Tombstone ratio becomes problematic
   -- Monitor: SELECT COUNT(*) and compare to delete rate
   ```

2. **Use TTL instead of explicit deletes**
   ```cql
   -- TTL is optimized for mass expiration
   INSERT ... USING TTL 86400;
   
   -- Explicit deletion creates individual tombstones
   DELETE FROM table WHERE pk = 'value';
   ```

3. **Lower gc_grace_seconds for high-delete workloads**
   ```cql
   CREATE TABLE logs (
     log_id UUID PRIMARY KEY,
     message TEXT
   ) WITH gc_grace_seconds = 86400;  -- 1 day instead of 10
   
   -- But: Risk of resurrection if nodes are down >1 day
   ```

4. **Monitor tombstone ratio**
   ```
   Use nodetool cfstats to check:
   - SSTable count
   - Tombstone count / total rows
   - Compaction rate
   
   Alert if tombstone ratio > 50%
   ```

5. **Don't query deleted data repeatedly**
   ```cql
   -- BAD: Repeatedly checking if row exists (tombstone reading)
   SELECT * FROM users WHERE user_id = 'deleted_user';  // Returns nothing, reads tombstone
   
   -- Better: Track deletion separately or use different access pattern
   ```

---

## TTL vs DELETE: Comparison

| Aspect | TTL | DELETE |
|--------|-----|--------|
| **Trigger** | Time | Explicit command |
| **When deleted** | After expiry | Immediately |
| **Tombstone** | Yes | Yes |
| **Best for** | Expiring data | One-off deletions |
| **Performance** | Optimized for mass expiry | Individual tombstones |
| **Use case** | Sessions, tokens, cache | Specific record deletion |

---

## Real-World Scenarios

### Scenario 1: User Sessions
```cql
CREATE TABLE user_sessions (
  session_id UUID PRIMARY KEY,
  user_id UUID,
  token TEXT,
  created_at TIMESTAMP
) WITH default_time_to_live = 3600;  -- 1-hour sessions

-- Insert session
INSERT INTO user_sessions (session_id, user_id, token, created_at)
VALUES (sess123, user456, 'token_xyz', now());
// Automatically expires after 1 hour

// No need for DELETE command
// No tombstone accumulation
// Clean, efficient pattern
```

### Scenario 2: Event Log with Archive
```cql
CREATE TABLE event_log (
  event_id UUID PRIMARY KEY,
  timestamp TIMESTAMP,
  message TEXT
) WITH default_time_to_live = 7776000;  // 90 days

INSERT INTO event_log (event_id, timestamp, message)
VALUES (evt123, now(), 'User logged in');
// After 90 days, automatically deleted

// Separately, run batch job to archive to long-term storage:
// SELECT * FROM event_log WHERE timestamp < 90_days_ago;
// Archive to S3/HDFS, then DELETE from Cassandra
```

### Scenario 3: Avoiding Tombstone Explosion
```
❌ BAD: Mass delete with explicit commands
BATCH:
  DELETE FROM completed_orders WHERE order_id = 'ord1';
  DELETE FROM completed_orders WHERE order_id = 'ord2';
  ... (1M times)
APPLY BATCH;

Result: 1M individual tombstones, compaction nightmare

✅ GOOD: Use time-bucket + TTL
CREATE TABLE completed_orders (
  completion_date DATE,
  order_id UUID,
  ...
  PRIMARY KEY (completion_date, order_id)
) WITH default_time_to_live = 2592000;  // 30 days

When order completes:
INSERT INTO completed_orders
  (completion_date, order_id, ...)
VALUES (today(), order_id, ...);

After 30 days: Entire partition expires automatically
No individual tombstones
Efficient cleanup
```

---

## Example Diagram
<div class="mermaid">
graph TD;
  A["Data Lifecycle"] --> B["INSERT"]
  B --> C{"Set TTL?"}
  
  C -->|"Yes"| D["Countdown starts"]
  D --> E["Time expires"]
  E --> F["Tombstone written"]
  F --> G["Read-repair delivers tombstone<br/>to replicas"]
  
  C -->|"No"| H["Data persists"]
  H --> I{"Explicit DELETE?"}
  
  I -->|"Yes"| F
  I -->|"No"| J["Forever"]
  
  F --> K["gc_grace_seconds"]
  K --> L{"Compaction runs?"}
  L -->|"Yes"| M["Tombstone deleted<br/>Space reclaimed"]
  L -->|"No"| N["Tombstone persists"]
  
  N --> O["Tombstone ratio increases<br/>Read perf degrades"]
</div>

---

## Summary
- **TTL**: Automatic expiration after time period; recommended for session data, tokens, temporary info.
- **Tombstones**: Markers for deleted/expired data; necessary for consistency but accumulate with deletes.
- **Compaction**: Background process that removes old tombstones; requires gc_grace_seconds to pass first.
- **Best practice**: Use TTL for mass expiration; minimize explicit deletes; monitor tombstone ratio.
- **Trade-off**: gc_grace_seconds vs. resurrection risk; longer window = safer, shorter = faster cleanup.
- **Monitor**: Watch tombstone ratios and compaction; adjust gc_grace_seconds based on workload.
