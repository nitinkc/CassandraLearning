# Core Concepts

Cassandra distributes data across nodes and data centers for fault tolerance and scalability. Understanding these fundamentals is essential to using Cassandra effectively.

## Definitions & Core Concepts

### Cluster
**Definition**: A cluster is a collection of interconnected Cassandra nodes that together form a single logical database.

**What it means**:
- Nodes communicate via gossip protocol
- Data is distributed and replicated across all nodes
- If one node fails, others still serve requests
- Linear scaling: add more nodes to handle more data/load
- All nodes are peers (no master/slave)

**Example**:
```
Cluster = Node1 + Node2 + Node3 + Node4 + ...
Each node holds a portion of data, coordinated via gossip
```

### Node
**Definition**: A node is a single Cassandra server instance (a physical or virtual machine).

**What it means**:
- Runs the Cassandra JVM process
- Has its own disk storage
- Participates in cluster communication
- Can read/write data locally
- Can be queried directly by clients

**Node Ring**:
Cassandra uses a consistent hash ring where each node owns a range of token values:
```
Ring: 0 -------- Node1 -------- Node2 -------- Node3 -------- Node1 (back to 0)
      [Ring 0]   [Ring 1]       [Ring 2]       [Ring 3]
```
Each partition's data goes to the node(s) responsible for that token range.

### Data Center
**Definition**: A data center is a logical grouping of Cassandra nodes, typically co-located physically or in the same cloud region.

**What it means**:
- Nodes in same DC have low latency between them
- Replication can be controlled per data center
- Enables geographic distribution (multi-region deployments)
- Each DC can serve read/write requests independently
- Survives entire DC failures

**Example**:
```
Cluster
├── Data Center 1 (US East) → Node1, Node2, Node3
└── Data Center 2 (EU) → Node4, Node5, Node6
```

### Partition Key
**Definition**: The partition key is a column (or combination of columns) that determines which node stores a row and how data is distributed across the cluster.

**What it means**:
- Cassandra hashes the partition key → gets a token (0 to 2^127)
- Token is matched to a node's token range
- All rows with same partition key go to same node(s)
- **Critical for performance**: poor choice = hot partitions

**Example**:
```cql
-- partition key = user_id
CREATE TABLE user_profile (
  user_id UUID PRIMARY KEY,
  name TEXT,
  email TEXT
);

INSERT INTO user_profile (user_id, name, email) 
VALUES (12345, 'Alice', 'alice@example.com');

-- Cassandra hashes user_id → finds responsible node → stores there
```

### Clustering Columns
**Definition**: Clustering columns determine the sort order of rows within a partition.

**What it means**:
- Define physical order of data on disk
- Efficient range queries within partition
- Must be used in query conditions (after partition key)
- Multiple clustering columns create nested sort order

**Example**:
```cql
CREATE TABLE user_posts (
  user_id UUID,
  post_date TIMESTAMP,  -- Clustering column
  post_id UUID,         -- Clustering column
  content TEXT,
  PRIMARY KEY (user_id, post_date, post_id)
);

-- Rows with user_id='123' are sorted by post_date, then post_id
-- Efficient query: "Get posts for user between dates X and Y"
SELECT * FROM user_posts 
WHERE user_id = '123' AND post_date > '2024-01-01' AND post_date < '2024-12-31';
```

### Replication Factor (RF)
**Definition**: Replication factor is the number of copies of each piece of data stored across the cluster.

**What it means**:
- RF=1: One copy of data (single point of failure)
- RF=3: Three copies of data (can lose 2 nodes and still serve)
- RF=5: Five copies (can lose 4 nodes)
- Each replica goes to different nodes
- Can be set per data center

**Example**:
```
Partition data = [Key='user123']

With RF=3:
- Copy 1 → Node1
- Copy 2 → Node2  
- Copy 3 → Node3

If Node1 fails, data still available from Node2 or Node3
```

**Choosing RF**:
- Typically RF=3 for production (balances redundancy and storage)
- Multi-DC: might be RF=2 in DC1 + RF=2 in DC2

### Consistency Levels
**Definition**: Consistency level is a parameter that controls how many replicas must acknowledge a read/write operation.

**What it means for writes**:
- `ONE`: Write succeeds when 1 replica acknowledges
- `QUORUM`: Write succeeds when majority (RF/2 + 1) acknowledge
- `ALL`: Write succeeds only when all replicas acknowledge

**What it means for reads**:
- `ONE`: Read returns after 1 replica responds (fastest, might be stale)
- `QUORUM`: Read from multiple replicas, return latest (balanced)
- `ALL`: Read all replicas, ensure freshness (slowest)

**Example Trade-offs**:
```
Write CL=ONE + Read CL=QUORUM → Fast writes, consistent reads
Write CL=QUORUM + Read CL=ONE → Consistent writes, fast reads
Write CL=ALL + Read CL=ONE → Slow writes, fast reads (not recommended)
```

### Hot Partitions
**Definition**: A partition that receives a disproportionate amount of read/write traffic compared to other partitions.

**What it means**:
- Single node becomes bottleneck
- Can't scale beyond that node's capacity
- Causes timeouts, slow responses
- Result of poor partition key design
- **Most common performance problem in Cassandra**

**Example of bad design**:
```cql
-- BAD: All data for single status goes to one partition
CREATE TABLE tasks (
  status TEXT,     -- ← Partition key!
  task_id UUID,
  PRIMARY KEY (status)
);

-- If 90% of tasks are "in_progress", that partition is hot!
-- One node handles all "in_progress" tasks → bottleneck
```

**Example of better design**:
```cql
-- BETTER: Distribute using date bucket
CREATE TABLE tasks (
  status TEXT,
  date_bucket DATE,
  task_id UUID,
  PRIMARY KEY ((status, date_bucket), task_id)
);

-- Now "in_progress" tasks spread across many partitions (one per day)
-- Load distributed evenly across nodes
```

---

## Relationships Between Concepts

<div class="mermaid">
graph LR;
  A["Cluster"]
  B["Node 1"]
  C["Node 2"]
  D["DC1"]
  E["DC2"]
  
  A -->|"contains"| D
  A -->|"contains"| E
  D -->|"contains"| B
  E -->|"contains"| C
  
  F["Table"]
  G["Partition Key"]
  H["Clustering"]
  
  F -->|"uses"| G
  F -->|"uses"| H
  G -->|"routes to"| B
  G -->|"creates hotspot"| I["Poor Design"]

