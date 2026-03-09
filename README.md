# Cassandra Learning Labs (CQL + Spring Boot)

This workspace is a structured, incremental learning path for Apache Cassandra with a runnable Spring Boot app. 
It is optimized for interview preparation: the labs start with must-know concepts and build toward advanced topics.

## Prerequisites
- Java 21
- Maven
- Docker (optional, for Cassandra container)
- Local Cassandra 5.0.6 running (or use the Docker compose provided)

## Quick Start

1) Start Cassandra with Docker (optional):

```shell
cd ~/Learn/CassandraSpring
# includes healthcheck and auto init job for ./docker/init.cql
docker compose -f docker/docker-compose.yml up
```

**To bring up the two-node, two-rack cluster and apply schema/data:**
```shell
cd ~/Learn/CassandraSpring
docker compose -f docker/docker-compose.yml up
# after both nodes are healthy, the init job seeds cassandra_labs
# to use both nodes, switch keyspaces to NetworkTopologyStrategy and RF=2 for datacenter1, e.g.:
docker compose -f docker/docker-compose.yml exec cassandra \
  cqlsh -e "ALTER KEYSPACE cassandra_labs WITH replication = {'class': 'NetworkTopologyStrategy','datacenter1':2};"
```

2) Schema and sample data are auto-applied by the init job. If you need to rerun manually:

```shell
docker compose -f docker/docker-compose.yml exec cassandra cqlsh -f /init/init.cql
```

3) Run the Spring Boot app:

```shell
cd /Users/PSP1000909/Learn/CassandraSpring/spring-boot-app
mvn spring-boot:run
```

4) Explore API docs (Swagger UI):

```text
http://localhost:8080/swagger-ui/index.html
```

## Learning Path (Most Important → Advanced)
1. Data modeling by query and primary key design
2. Partition keys vs clustering keys
3. Denormalization and query-driven tables
4. Consistency levels and lightweight transactions (LWT)
5. Batching (logged vs unlogged)
6. TTL, tombstones, and deletes
7. Secondary indexes and materialized views
8. Aggregation limits and filtering constraints

Labs are in `labs/` and align with the above order.

## Spring Boot Endpoints
These endpoints let you observe Cassandra behavior with real queries.

Create user (writes to two tables with a batch):
```shell
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"email":"alex@example.com","fullName":"Alex Chen"}'
```

Get by user id:
```shell
curl http://localhost:8080/api/users/{userId}
```

Query by email (denormalized table):
```shell
curl "http://localhost:8080/api/users/by-email?email=alex@example.com"
```

Create order (partitioned by user):
```shell
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":"{userId}","amount":129.99,"status":"CREATED"}'
```

Get orders for user:
```shell
curl http://localhost:8080/api/orders/{userId}
```

Learning plan JSON:
```shell
curl http://localhost:8080/api/learning-plan
```

## Interview Prep
Use `labs/interview-questions.md` for a curated list of questions with short guidance. Work through the labs first, then answer the questions using the schema and app in this repo.

## Notes
- The application is intentionally simple and focused on Cassandra behavior.
- Schema is managed manually via `docker/init.cql` and auto-applied by docker compose.


Axon Ops workspace