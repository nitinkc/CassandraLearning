# Consistency, LWT & Batching

Cassandra offers tunable consistency levels and supports lightweight transactions (LWT) and batching for atomic writes. These are powerful tools that must be used carefully.

## Definitions & Core Concepts

### Consistency Levels
**Definition**: A consistency level is a configuration parameter that specifies how many replicas must acknowledge a read or write operation before the operation is considered successful.

**What it means**:
- Cassandra replicates data across multiple nodes (replication factor)
- Before returning success, Cassandra can wait for acknowledgment from different numbers of replicas
- More replicas = stronger consistency, but slower latency
- Fewer replicas = weaker consistency, but faster latency

### Write Consistency Levels

**ONE**
```
Write Operation: Insert data
1. Client sends write to coordinator
2. Coordinator writes to 1 replica (locally or remote)
3. Coordinator returns success immediately
4. Other replicas get write asynchronously

Risk: If that 1 replica fails before replication, data is lost
Latency: Fastest
Use case: Non-critical data, metrics, logs
```

**QUORUM**
```
Replicas = 3
QUORUM = 3/2 + 1 = 2

1. Client sends write to coordinator
2. Coordinator writes to 2 out of 3 replicas (waits for acks)
3. After 2 acknowledge, coordinator returns success
4. 3rd replica gets asynchronous write

Risk: Acceptable - at least 2 copies exist
Latency: Moderate
Use case: Most production workloads (recommended default)
```

**ALL**
```
Replicas = 3
ALL = 3

1. Client sends write to coordinator
2. Coordinator writes to all 3 replicas (waits for all acks)
3. Only after all 3 acknowledge does coordinator return success
4. No asynchronous writes

Risk: None - maximum durability
Latency: Slowest (must wait for slowest replica)
Use case: Critical data, when you need absolute certainty
```

**LOCAL_QUORUM**
```
RF = 2 in US DC, 2 in EU DC
LOCAL_QUORUM = quorum within local DC only

1. Write goes to quorum of local DC only
2. Ignores remote DCs for acknowledgment
3. Remote DCs replicate asynchronously

Latency: Better (no remote DC latency)
Risk: Better availability (local DC can be isolated)
Use case: Multi-DC deployments, fast writes
```

### Read Consistency Levels

**ONE**
```
1. Client requests data
2. Coordinator asks any 1 replica for the value
3. Returns immediately without checking others
4. Might return stale data

Result: Stale data possible
Latency: Fastest
Use case: Cache-like reads, where stale is acceptable
```

**QUORUM**
```
Replicas = 3, QUORUM = 2

1. Client requests data
2. Coordinator asks all 3 replicas
3. After 2 respond, coordinator gets the most recent value
4. Uses timestamps/version vectors to determine "most recent"
5. Returns to client

Result: Consistent (at least 2 of 3 agree)
Latency: Moderate
Use case: Most reads (recommended default)
```

**ALL**
```
1. Client requests data
2. Coordinator asks all 3 replicas
3. Waits for all 3 responses
4. Ensures all copies agree before returning

Result: Guaranteed fresh, consistent data
Latency: Slowest
Use case: Critical reads, when you need absolute certainty
```

### Consistency Trade-offs

```
Write CL     | Read CL    | Result              | Latency
ONE          | ONE        | Very stale possible | ⚡⚡⚡ Fastest
ONE          | QUORUM     | Eventual consistency| ⚡⚡
QUORUM       | ONE        | Eventual consistency| ⚡⚡
QUORUM       | QUORUM     | Strong consistency  | ⚡
ALL          | ONE        | Fresh writes, stale reads ❌ Confusing
ALL          | ALL        | Absolute consistency| ❌ Slowest
```

**Why QUORUM + QUORUM is popular**:
- With 3 replicas and RF=3:
  - Write QUORUM = 2 replicas
  - Read QUORUM = 2 replicas
  - Overlap guarantees: 2 + 2 = 3 replicas, so must overlap by at least 1
  - That 1 replica has the latest write
  - Read hits latest replica with probability = freshness

---

## Lightweight Transactions (LWT)

### Definition
**Definition**: Lightweight transactions are conditional writes that use the Paxos consensus algorithm to provide linearizable (strongly consistent) semantics for a single row.

**What it means**:
- Allows atomic compare-and-set operations
- `IF` condition is checked before write commits
- Either entire operation succeeds (condition true + write) or fails (condition false)
- Not a multi-row transaction; just single-row atomicity
- More expensive than regular writes (Paxos protocol overhead)

### LWT Patterns

**IF NOT EXISTS**
```cql
-- Only insert if row doesn't exist
INSERT INTO users (user_id, email, name) 
VALUES (uuid1, 'alice@example.com', 'Alice')
IF NOT EXISTS;

-- Cassandra Paxos protocol ensures:
-- 1. Check: does row exist?
-- 2. If NO: insert and return success
// 3. If YES: return failure without inserting
// 4. No race conditions: atomic check + write
```

**Conditional Update**
```cql
-- Only update if current value matches
UPDATE user_balance 
SET balance = 1000 
WHERE user_id = 'acct1'
IF balance = 500;

-- What this does:
// 1. Read current balance
// 2. Check if balance == 500
// 3. If yes: update to 1000, return applied=true
// 4. If no: don't update, return applied=false (with current value)

// Use case: Prevent race conditions in updates
// Example: Two concurrent withdrawals from same account
```

**Multiple Conditions**
```cql
UPDATE reservation
SET status = 'confirmed'
WHERE reservation_id = 'res123'
IF status = 'pending' AND version = 1;

// All conditions must be true for update to apply
```

### How Paxos Works (Simplified)

```
Client: "Update row X if condition Y"

Phase 1: Prepare
- Coordinator asks replicas: "Anyone working on row X?"
- Replicas respond: "No" or "Yes, version Z"
- Pick highest version

Phase 2: Promise
- Replicas promise not to accept other updates for this round
- Tell coordinator the current value

Phase 3: Propose
- Coordinator proposes: "Check condition Y, if true apply update"
- Replicas check condition against current value
- If condition true AND no one else updated: accept
- If condition false OR someone else updated: reject

Phase 4: Learn
- Coordinator tells replicas: "Decision was X" (applies to all)
- All replicas apply same decision
- Coordinator tells client: applied=true/false
```

### LWT Performance Characteristics

| Aspect | Impact |
|--------|--------|
| **Latency** | 2-5x slower than regular writes (4-round Paxos protocol) |
| **Throughput** | Much lower (Paxos serializes writes to same partition) |
| **Consistency** | Strongest: linearizable within partition |
| **Contention** | High contention = timeouts (Paxos aborts) |

### When to Use LWT

✅ **Good use cases**:
- Uniqueness constraints (user registration with unique email)
- Optimistic locking (version-based updates)
- Leader election (single writer)
- Preventing accidental overwrites

❌ **Avoid**:
- High-throughput writes (conflicts = lost throughput)
- Frequent contention (timeouts, slow)
- When regular writes suffice (unnecessary overhead)

---

## Batching

### Definition
**Definition**: Batching is sending multiple writes to Cassandra in a single request, potentially with atomic semantics.

**What it means**:
- Client: "Execute these 5 writes together"
- Coordinator: processes batch atomically
- Either all succeed or all fail (no partial batches)
- Multiple tables supported
- Different from database transactions (no rollback/commit)

### Types of Batches

**Logged Batch** (Atomic)
```cql
BEGIN BATCH
  INSERT INTO users (user_id, name) VALUES (uuid1, 'Alice');
  INSERT INTO user_emails (email, user_id) VALUES ('alice@ex.com', uuid1);
  UPDATE user_count SET total = total + 1;
APPLY BATCH;

-- What happens:
// 1. Write batch to batchlog (on 2 replicas, quorum)
// 2. Execute all 3 writes
// 3. Delete batchlog entry
// 4. Return success

// If coordinator crashes between step 3 and 4:
// - Batchlog exists on replicas
// - Background process replays batch
// - Guaranteed atomicity
```

**Unlogged Batch** (Not Atomic)
```cql
BEGIN UNLOGGED BATCH
  INSERT INTO ...
  UPDATE ...
APPLY BATCH;

// No batchlog - writes sent in parallel
// If some succeed and some fail: no guarantee all applied
// Faster but no atomicity
// Use when you don't need atomicity
```

### Batching Trade-offs

| Aspect | Logged Batch | Unlogged Batch | Individual Writes |
|--------|--------------|---|---|
| **Atomicity** | ✓ Guaranteed | ✗ Not guaranteed | N/A |
| **Latency** | Higher (batchlog) | Lower | Lowest (parallel) |
| **Use case** | Multi-table inserts | Best effort writes | Most writes |

### Batching Anti-Patterns

**❌ Large Batches**
```cql
-- BAD: Batching 10,000 writes
BEGIN BATCH
  INSERT INTO events ...
  INSERT INTO events ...
  ... (10,000 times)
APPLY BATCH;

// Problems:
// 1. Coordinator must hold all in memory
// 2. Single node processes entire batch (no parallelism)
// 3. If batch fails, all 10K writes are lost
// 4. Timeouts likely

// Better: Split into smaller batches (10-100 writes)
// Or: Use pipelining (send writes in parallel, not in batch)
```

**❌ Batching Different Partition Keys**
```cql
BEGIN BATCH
  INSERT INTO table1 (pk=a, data) VALUES ('a', 'data1');
  INSERT INTO table1 (pk=b, data) VALUES ('b', 'data2');  -- Different partition
APPLY BATCH;

// Cassandra sends writes to different nodes
// No benefit from batching (writes are remote)
// Still pay cost of batchlog

// Better: Don't batch, just send separately (parallel)
```

### When to Use Batching

✅ **Good use cases**:
- Related writes to multiple tables (user + user_emails)
- Small number of rows (5-50 writes)
- Atomicity is important
- Same partition key (or closely related)

❌ **Avoid**:
- Bulk inserts (10K+ rows) → use pipelining instead
- Unrelated writes → no atomicity needed
- High-throughput scenarios → batching is slow

---

## Consistency, LWT & Batching: Decision Tree

<div class="mermaid">
graph TD;
  A["Need to decide on consistency/concurrency"] --> B["Is this critical data?"]
  
  B -->|"No (logs, metrics)"| C["CL ONE reads+writes<br/>fast, occasional loss OK"]
  B -->|"Yes (accounts, config)"| D["CL QUORUM reads+writes<br/>balanced"]
  B -->|"Very critical"| E["CL ALL or LWT<br/>slowest, safest"]
  
  F["Multiple writes?"] -->|"No"| G["Single write<br/>use CL only"]
  F -->|"Yes"| H["Need atomic?"]
  
  H -->|"No"| I["Send in parallel<br/>no batch"]
  H -->|"Yes"| J["Few writes?"]
  
  J -->|"<100"| K["Use BATCH<br/>logged"]
  J -->|">100"| L["Split into<br/>smaller batches"]
  
  M["Multiple same values?"] -->|"Yes (10K writes)"| N["Use LWT?<br/>NO! Avoid contention"]
  M -->|"No"| O["OK for LWT<br/>if needed"]

