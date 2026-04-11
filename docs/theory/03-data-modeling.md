# Data Modeling

Cassandra uses query-first, denormalized data modeling for fast, predictable reads. This is a fundamental paradigm shift from relational database design.

## Definitions & Core Concepts

### Query-First Design
**Definition**: Query-first design means identifying your access patterns first, then building tables specifically to satisfy those queries efficiently.

**What it means**:
- Design starts with "What queries will my application run?"
- Each query pattern typically gets its own table
- No query optimization needed (table structure = query structure)
- Opposite of normalization (which minimizes duplication)

**Why it matters**:
```
Relational approach:
1. Design normalized schema
2. Write query
3. Database optimizer finds best access path
4. Execute

Cassandra approach:
1. Identify query patterns (user by email, user by phone, etc.)
2. Design table structure exactly for that query
3. Execute (no optimization needed)
4. Result: predictable performance
```

### Denormalization
**Definition**: Denormalization is intentionally duplicating data across multiple tables to support different query patterns without joins.

**What it means**:
- Same data stored in multiple tables, different primary keys
- Breaks normalization rules (3NF, BCNF)
- Necessary in Cassandra because there are no joins
- Requires careful management to keep duplicates in sync

**Example**:
```cql
-- Normalized (relational):
users table: user_id → name, email, phone
orders table: order_id → user_id (foreign key), amount

-- Denormalized (Cassandra):
Table 1: user_by_email
  user_email (PK) → user_id, name, phone

Table 2: user_by_phone
  user_phone (PK) → user_id, name, email

Table 3: orders_by_user
  user_id (PK) → order_id, amount

Table 4: orders_by_date
  order_date (PK) → order_id, user_id, amount

When updating user email:
- Must update in user_by_email
- Must update all orders_by_user rows with that user_id
- Requires application logic or triggers
```

**Pros and Cons**:
- ✅ Fast, predictable queries
- ✅ No complex joins
- ❌ Larger storage (data duplication)
- ❌ Complex writes (update multiple tables)
- ❌ Risk of inconsistency if updates fail partway

### Time-Series Data
**Definition**: Time-series data is measurements or events recorded over time, indexed by timestamp.

**What it means in Cassandra**:
- Extremely common pattern (logs, metrics, IoT sensors)
- Naive approach: partition by entity, insert all data
- Problem: unbounded partition growth (millions of rows per partition)
- Solution: use time buckets to split across partitions

**Unbounded Partition Problem**:
```cql
-- ❌ BAD: All metric data for sensor goes to one partition
CREATE TABLE metrics (
  sensor_id UUID PRIMARY KEY,
  timestamp TIMESTAMP,
  value DOUBLE
);

INSERT INTO metrics VALUES (sensor1, 2024-01-01 00:00, 25.5);
INSERT INTO metrics VALUES (sensor1, 2024-01-01 00:01, 25.6);
INSERT INTO metrics VALUES (sensor1, 2024-01-01 00:02, 25.7);
... (millions more for same sensor_id)

-- Result: Single partition grows unbounded
-- Single node handles all sensor1 data
-- Node runs out of memory trying to compact this partition
```

**Time Bucket Solution**:
```cql
-- ✅ GOOD: Time-bucket the partition key
CREATE TABLE metrics (
  sensor_id UUID,
  date_bucket DATE,  -- New: partition by day
  timestamp TIMESTAMP,
  value DOUBLE,
  PRIMARY KEY ((sensor_id, date_bucket), timestamp)
);

INSERT INTO metrics VALUES (sensor1, 2024-01-01, 2024-01-01 00:00, 25.5);
INSERT INTO metrics VALUES (sensor1, 2024-01-01, 2024-01-01 00:01, 25.6);
-- ...day 1 data...
INSERT INTO metrics VALUES (sensor1, 2024-01-02, 2024-01-02 00:00, 25.5);
INSERT INTO metrics VALUES (sensor1, 2024-01-02, 2024-01-02 00:01, 25.6);

-- Result: Each day's data is a separate partition
-- Bounded size: 24 hours * 60 minutes = 1440 rows per partition
-- Scales horizontally across cluster
```

### ALLOW FILTERING
**Definition**: `ALLOW FILTERING` is a CQL clause that bypasses Cassandra's safety checks and allows filtering on columns not in the primary key.

**What it means**:
- Normally, CQL enforces queries matching primary key structure
- ALLOW FILTERING allows arbitrary filtering
- Causes client-side filtering or full table scans
- Performance degradation
- Temporary workaround for schema problems

**Example**:
```cql
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  name TEXT,
  email TEXT,
  country TEXT
);

-- ✅ GOOD: Query by primary key (partition key)
SELECT * FROM users WHERE user_id = '123';

-- ❌ BAD: Filtering by non-key column
SELECT * FROM users WHERE email = 'alice@example.com';
-- Error: Cannot execute this query as it might involve data from multiple partitions

-- ❌ VERY BAD: With ALLOW FILTERING (full scan)
SELECT * FROM users WHERE email = 'alice@example.com' ALLOW FILTERING;
-- This scans EVERY row in the table to find matching emails
-- Works on small tables, disastrous on large ones
```

**When ALLOW FILTERING might be acceptable**:
- Development/testing environments
- Querying very small tables (< 100K rows)
- Ad-hoc queries (not in production code)
- After you've already filtered by partition key

### Relationships & Wide Rows
**Definition**: Modeling one-to-many or many-to-many relationships using denormalized wide rows instead of joins.

**One-to-Many Example**:
```cql
-- User has many orders
CREATE TABLE user_orders (
  user_id UUID,
  order_id UUID,
  amount DECIMAL,
  order_date TIMESTAMP,
  PRIMARY KEY (user_id, order_id)  -- user_id = partition, order_id = clustering
);

-- Get all orders for a user
SELECT * FROM user_orders WHERE user_id = '123';
-- Returns potentially hundreds of rows, all in one partition
-- Efficient: single partition read, no joins needed
```

**Many-to-Many Example**:
```cql
-- Students enrolled in courses
CREATE TABLE student_courses (
  student_id UUID,
  course_id UUID,
  enrollment_date TIMESTAMP,
  PRIMARY KEY (student_id, course_id)
);

CREATE TABLE course_students (
  course_id UUID,
  student_id UUID,
  enrollment_date TIMESTAMP,
  PRIMARY KEY (course_id, student_id)
);

-- Must maintain both tables when enrollment changes
-- Dual-write pattern
```

---

## Complete Data Modeling Workflow

### Step 1: Identify Access Patterns
```
Questions to ask:
- "How will users query the data?"
- "What filters will be applied?"
- "What sorting is needed?"
- "What's the read/write ratio?"

Example answers:
✓ "Find user by email"
✓ "Get all orders for user between dates X and Y"
✓ "Get latest 10 posts from user"
✓ "Count messages by user per day"
```

### Step 2: Design Primary Keys
```
For each access pattern, design a table:

Query: "Find user by email"
→ Table: users_by_email (email PRIMARY KEY)

Query: "Get orders for user between dates"
→ Table: orders_by_user_date (user_id, order_date PRIMARY KEY)

Query: "Get latest posts from user"
→ Table: posts_by_user (user_id, post_date DESC PRIMARY KEY)
```

### Step 3: Add Denormalized Columns
```
users_by_email table needs:
- user_id (for lookups)
- name, phone, country (user data)
- Do NOT include rarely-needed data (save space)
```

### Step 4: Plan Write Strategy
```
When user email changes:
- Update users_by_email
- Are there other tables with email? Update them too
- Use batch for atomic updates
- Handle failures gracefully (eventual consistency)
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|---|---|---|
| **Unbounded time-series** | Partition grows forever | Use time buckets (date_bucket in PK) |
| **ALLOW FILTERING** | Full table scans | Redesign schema for query patterns |
| **High-cardinality partition key** | Too many partitions | Use composite key or bucketing |
| **Low-cardinality partition key** | Hot partitions | Add high-cardinality component |
| **No clustering column** | Can't do range queries | Add timestamp/sequence clustering column |
| **No denormalization** | Need joins (not supported) | Duplicate data across tables |

---

## Example Diagram
<div class="mermaid">
graph TD;
  A["Identify Queries"] --> B["Design PKs"]
  B --> C["Choose Partition Key"]
  C -->|"High cardinality"| D["Distributed evenly"]
  C -->|"Low cardinality"| E["Hot partition!"]
  B --> F["Choose Clustering Columns"]
  F --> G["Efficient ranges"]
  A --> H["Denormalize"]
  H --> I["Multiple tables"]
  I --> J["Dual-write logic"]
</div>

---

## Summary
- **Query-first**: Design tables for your queries, not for normalization.
- **Denormalization**: Duplicate data across tables to avoid joins; manage carefully.
- **Time-series**: Always use time buckets to prevent unbounded partitions.
- **ALLOW FILTERING**: Symptom of schema mismatch; fix by redesigning table structure.
- **Wide rows**: Use for one-to-many relationships; no joins needed.
- **Access patterns**: Drive all schema decisions; identify them first.
