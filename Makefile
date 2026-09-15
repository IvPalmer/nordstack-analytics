# Host ports and connection URLs can be overridden in .env (see .env.example).
-include .env
export

PY  ?= python3.12
DBT  = .venv/bin/dbt --profiles-dir .
AIRFLOW_CONSTRAINTS = https://raw.githubusercontent.com/apache/airflow/constraints-3.3.1/constraints-3.12.txt

.PHONY: bootstrap db venv ingest deps build test docs clean nuke airflow-test

bootstrap: db venv ingest deps build   ## clean clone -> loaded, built, tested warehouse

db:
	docker compose up -d --wait

venv:
	test -d .venv || $(PY) -m venv .venv
	.venv/bin/pip install --quiet --upgrade pip
	.venv/bin/pip install --quiet -r requirements.txt

ingest:
	.venv/bin/python ingestion/load_source_system.py
	.venv/bin/python ingestion/sync_to_warehouse.py

deps:
	$(DBT) deps

build:
	$(DBT) build

test:
	$(DBT) test

docs:
	$(DBT) docs generate && $(DBT) docs serve

clean:
	$(DBT) clean

nuke:   ## stop both databases and drop their volumes
	docker compose down -v

airflow-test:   ## parse the DAG in an isolated Airflow install
	test -d airflow/.venv || $(PY) -m venv airflow/.venv
	airflow/.venv/bin/pip install --quiet -r airflow/requirements.txt --constraint $(AIRFLOW_CONSTRAINTS)
	airflow/.venv/bin/pytest airflow/tests -q
