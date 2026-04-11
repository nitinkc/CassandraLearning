# Indexes & Materialized Views

Indexes and materialized views in Cassandra help support additional query patterns, but both have important limitations and trade-offs that must be understood.

## Definitions & Core Concepts

### Secondary Indexes (SI)
**Definition**: A secondary index is an index on a column that is not part of the primary key, allowing queries on that column.

**What it means**:
- Normally, only queries on primary key columns are efficient
- Secondary index creates a reverse mapping: `column_value → primary_key`
- Query can find rows by secondary index column value
- Index is distributed (each node builds index for local data)
- Queries still touch multiple nodes

**How secondary indexes work**:
```cql
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  email TEXT,
  name TEXT,
  country TEXT
);

-- Without index
SELECT * FROM users WHERE email = 'alice@example.com';
-- ERROR: Cannot execute (must use partition key)

-- With index
CREATE INDEX ON users(email);

SELECT * FROM users WHERE email = 'alice@example.com';
-- Now works! But how?
```

**Under the hood**:
```
Original table on Node1:
user_id1 | email1 | name1 | country1
user_id2 | email2 | name2 | country2
...

Secondary index on Node1:
email1 → user_id1
email2 → user_id2
...

Query for email='alice@example.com':
1. Look up email in index on each node
2. Get user_id from index
3. Fetch full row using user_id as primary key
4. Return to client
```

### Materialized Views (MV)
**Definition**: A materialized view is an automatically maintained denormalized copy of a table with a different primary key.

**What it means**:
- Main table: `users_by_id (user_id PRIMARY KEY)`
- Materialized view: `users_by_email (email PRIMARY KEY)`
- When main table changes, view is automatically updated
- Can query the view directly (different PK = different access pattern)
- View is durably stored (not computed on-the-fly)

**Example**:
```cql
-- Base table
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  email TEXT,
  name TEXT
);

-- Materialized view (automatic denormalization)
CREATE MATERIALIZED VIEW users_by_email AS
  SELECT user_id, email, name FROM users
  WHERE email IS NOT NULL AND user_id IS NOT NULL
  PRIMARY KEY (email, user_id);

-- Now both queries are efficient:
SELECT * FROM users WHERE user_id = '123';  -- Queries base table
SELECT * FROM users_by_email WHERE email = 'alice@example.com';  -- Queries MV
```

### Cardinality
**Definition**: Cardinality is the number of distinct values a column can have.

**Examples**:
- **Low cardinality**: country (250 values), status (active/inactive), gender (M/F)
- **Medium cardinality**: month (12 values), day_of_week (7 values)
- **High cardinality**: email (millions), phone_number (millions), user_id (billions)

**Why it matters**:
- Secondary indexes on low-cardinality columns = each index entry returns many rows
- Secondary indexes on high-cardinality columns = each index entry returns few rows
- Cassandra excels at high-cardinality, struggles with low-cardinality

---

## Secondary Indexes: Deep Dive

### When Secondary Indexes Work Well

**✅ Low-cardinality + small result sets**
```cql
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  status TEXT,        -- Low cardinality: "active", "inactive"
  country TEXT        -- Low cardinality: ~250 countries
);

CREATE INDEX ON users(status);

-- Query: Get all inactive users in USA
SELECT * FROM users WHERE country = 'USA' AND status = 'inactive';
-- Scans country=USA (maybe 10K rows), filters status=inactive (maybe 100 rows)
-- Acceptable because result set is small
```

**✅ Query already filters by partition key**
```cql
CREATE TABLE posts (
  user_id UUID,
  post_id UUID,
  status TEXT,
  PRIMARY KEY (user_id, post_id)
);

CREATE INDEX ON posts(status);

-- Query: Get published posts for specific user
SELECT * FROM posts WHERE user_id = '123' AND status = 'published' ALLOW FILTERING;
-- Queries partition for user_id='123' (bounded), then filters status
-- Efficient: single partition read
```

### When Secondary Indexes Fail

**❌ High-cardinality + large result sets**
```cql
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  email TEXT,        -- High cardinality: millions of values
  name TEXT
);

CREATE INDEX ON users(email);

-- Query: Get user by email
SELECT * FROM users WHERE email = 'alice@example.com';

-- Problem:
-- 1. Each node executes this query independently
-- 2. Node1's email index might have 1 row, Node2's might have 0, Node3 might have 1
-- 3. Client must query all nodes to get the answer
-- 4. Unpredictable latency (depends on how many nodes are queried)
// 5. Actually fast in practice, but not guaranteed
```

**❌ Without partition key filter (full scan)**
```cql
SELECT * FROM users WHERE status = 'active' ALLOW FILTERING;

-- Problems:
// 1. Must query all nodes
// 2. Each node might have thousands of matching rows
// 3. Network overhead: aggregate results from all nodes
// 4. Memory pressure: assembling large result sets
```

### Secondary Index Performance Considerations

| Scenario | Performance | Reason |
|----------|-------------|--------|
| **Low-cardinality index** | ⚠️ Warning | Each index value maps to many rows |
| **High-cardinality index** | ⚠️ Unpredictable | Depends on data distribution |
| **Without partition key** | ❌ Poor | Queries all nodes |
| **With partition key** | ✅ Good | Single node query + index |
| **Large result sets** | ❌ Poor | Network overhead, memory pressure |
| **Small result sets** | ✅ OK | Acceptable overhead |

---

## Materialized Views: Deep Dive

### How Materialized Views Work

```cql
-- Base table
CREATE TABLE orders (
  order_id UUID PRIMARY KEY,
  customer_id UUID,
  order_amount DECIMAL,
  order_date TIMESTAMP
);

-- Materialized view: query by customer
CREATE MATERIALIZED VIEW orders_by_customer AS
  SELECT order_id, customer_id, order_amount, order_date
  FROM orders
  WHERE customer_id IS NOT NULL
  PRIMARY KEY (customer_id, order_id);

-- When you INSERT into orders:
INSERT INTO orders (order_id, customer_id, order_amount, order_date)
VALUES (uuid1, cust123, 100.00, '2024-01-01');

-- Cassandra automatically updates orders_by_customer:
INSERT INTO orders_by_customer (customer_id, order_id, order_amount, order_date)
VALUES (cust123, uuid1, 100.00, '2024-01-01');

-- When you DELETE from orders, view is also updated
```

### Advantages of Materialized Views
- ✅ **Automatic denormalization**: No application logic for dual-writes
- ✅ **Consistent by design**: View updates are atomic with base table
- ✅ **Multiple access patterns**: One table, multiple query patterns
- ✅ **Transparent**: Queries don't know if they're hitting base or view

### Disadvantages of Materialized Views
- ❌ **Write amplification**: Every write goes to base table + all views
- ❌ **Potential consistency issues**: Can lag under high load
- ❌ **No guaranteed durability**: Lost writes possible in certain failure scenarios
- ❌ **Limited WHERE clauses**: Cannot filter on non-key columns when creating
- ❌ **Operational complexity**: Must manage lifecycle together

### Consistency Issues with Materialized Views

**The Problem**:
```
Time: T0
  Write to base table succeeds

Time: T1
  Write starts replicating to view
  
Time: T2
  Reading from base table → sees write
  
Time: T3
  Reading from view → might NOT see write yet
  
Result: Temporary inconsistency between base table and view
```

**In production**:
- Cassandra's "view updates are part of write" is not always true under failures
- If a node crashes during view update, view can permanently lag
- Many teams use explicit dual-write pattern instead (more control)

---

## Secondary Indexes vs Materialized Views vs Dual-Writes

| Feature | Secondary Index | Materialized View | Dual-Write |
|---------|-----------------|-------------------|-----------|
| **Automatic updates** | ✓ | ✓ | ✗ |
| **Multiple PK patterns** | Limited | ✓ | ✓ |
| **Performance** | Unpredictable | Good | Good |
| **Consistency** | Eventually | Eventually (risky) | Application-controlled |
| **Complexity** | Low | Medium | High |
| **Recommended use** | Low-cardinality filters | Simple denormalization | Critical data |

---

## Best Practices & Patterns

### Pattern 1: Secondary Index for Low-Cardinality
```cql
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  status TEXT,
  country TEXT
);

CREATE INDEX ON users(status);

-- Good: Status has few values, index lookup is efficient
SELECT * FROM users WHERE status = 'active';

-- Better: Use partition key first, then filter
SELECT * FROM users WHERE status = 'active' AND user_id = '123' ALLOW FILTERING;
```

### Pattern 2: Materialized View for Simple Denormalization
```cql
-- Base table: query by order_id
CREATE TABLE orders (
  order_id UUID PRIMARY KEY,
  customer_id UUID,
  amount DECIMAL,
  order_date TIMESTAMP
);

-- MV: query by customer
CREATE MATERIALIZED VIEW orders_by_customer AS
  SELECT order_id, customer_id, amount, order_date
  FROM orders
  WHERE customer_id IS NOT NULL
  PRIMARY KEY (customer_id, order_date, order_id);
```

### Pattern 3: Explicit Dual-Write (For Critical Data)
```cql
// In application code:
// When inserting order:
try {
  // Write 1: Main table
  session.execute(insertOrderQuery);
  
  // Write 2: Secondary table for different access pattern
  session.execute(insertOrderByCustomerQuery);
  
} catch (Exception e) {
  // Handle failure: reconciliation process
  log.error("Order write failed", e);
  // Can manually repair using sync job
}
```

---

## Example Diagram
<div class="mermaid">
graph TD;
  A["Index/View Decision"] --> B["Query Pattern"]
  B -->|"Low-card, small result"| C["Secondary Index"]
  B -->|"Simple denorm, automatic"| D["Materialized View"]
  B -->|"Critical, complex sync"| E["Dual-Write"]
  
  C -->|"Risk: full scan"| F["Monitor Performance"]
  D -->|"Risk: consistency lag"| F
  E -->|"Risk: app complexity"| F
  
  F -->|"Slow?"| G["Redesign schema<br/>or add partition key"]
</div>

---

## Real-World Scenarios

### Scenario 1: User Lookup by Email
```
Business need: "Find user by email"
Options:
1. SI on email → unpredictable (high cardinality)
2. MV with email PK → risky (consistency issues)
3. Dual-write: users_by_id + users_by_email → best practice

Best choice: Dual-write (option 3)
Reason: Email is high-cardinality, lookup must be consistent
```

### Scenario 2: Filter by Status
```
Business need: "Get all active users"
Options:
1. SI on status → acceptable (low cardinality)
2. MV with status PK → overkill
3. Dual-write → too complex

Best choice: SI (option 1)
Reason: Status has few values, filter makes sense
```

### Scenario 3: Orders by Customer
```
Business need: "Get all orders for customer" + "Get order by ID"
Options:
1. SI → doesn't give you both patterns
2. MV → good fit
3. Dual-write → also works

Best choice: MV (option 2)
Reason: Simple denormalization, automatic sync, both patterns supported
```

---

## Summary
- **Secondary Indexes**: Use for low-cardinality filters only. Avoid high-cardinality or full-table-scan queries.
- **Materialized Views**: Useful for simple denormalization, but watch for consistency issues under failures.
- **Dual-Writes**: Best practice for critical data; gives application control over consistency.
- **When in doubt**: Add the partition key or clustering column to support your query. Avoid indexes and views as a shortcut for bad schema design.
- **Test performance**: Always test indexes/views with production-scale data before deploying.
