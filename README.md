# Cassandra Learning Labs (CQL + Spring Boot)
[https://nitinkc.github.io/CassandraSpringBootLearning/](https://nitinkc.github.io/CassandraSpringBootLearning/)

## Prerequisites
- Java 21
- Maven
- Docker (optional, for Cassandra container)
- Local Cassandra 5.0.6 running (or use the Docker compose provided)

## Initial Setup

Create and activate a virtual environment, then install docs tooling:

```sh
python3 -m venv .venv && echo 'Created venv'
```

```shell
source .venv/bin/activate && pip install -r requirements.txt
```

## Start Cassandra (Docker)

```shell
docker compose -f docker/docker-compose.yml up
```

## Apply Schema (if needed)

```shell
docker compose -f docker/docker-compose.yml exec cassandra cqlsh -f /init/init.cql
```

## Run the Spring Boot App

```shell
cd ./spring-boot-app
mvn spring-boot:run
```
