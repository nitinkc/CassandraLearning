# Cassandra Learning Labs (CQL + Spring Boot)

- [Detailed Documentation and Tutorial](https://nitinkc.github.io/CassandraLearning/)

- [Cassandra with Docker Learning Repo](https://github.com/nitinkc/CassandraLearning)

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

The schema will be automatically initialized via the `cassandra-init` service once the cluster is healthy (this takes ~30-60 seconds).

## Apply Schema Manually (if needed)

If you need to re-apply the schema or run it separately:

```shell
# Option 1: From project root
docker compose -f docker/docker-compose.yml exec cassandra cqlsh < docker/init.cql

# Option 2: From docker directory
cd docker
docker compose exec cassandra cqlsh < init.cql
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

On code push to main, GitHub Actions will automatically build and deploy the docs to GitHub Pages.
You can view the live docs at https://nitinkc.github.io/CassandraLearning/ after deployment.

