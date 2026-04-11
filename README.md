# Cassandra Learning Labs (CQL + Spring Boot)
[https://nitinkc.github.io/CassandraSpringBootLearning/](https://nitinkc.github.io/CassandraSpringBootLearning/)

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

## Docs (MkDocs)

Run the project documentation locally or publish it online.

Locally (recommended in a venv):

```bash
# create and activate venv (run from project root)
python3 -m venv .venv
source .venv/bin/activate

# upgrade pip and install docs deps
python -m pip install --upgrade pip
pip install -r ./requirements.txt

# serve with live reload (open http://127.0.0.1:8000)
mkdocs serve -a 127.0.0.1:8000
```

Build the static site:

```bash
mkdocs build -d ./site
# then locally open the built index
open ./site/index.html
```

Publish to GitHub Pages (quick):

```bash
# make sure your repo is committed and has a remote (origin)
mkdocs gh-deploy --force
```

