# make exports the connection settings in .env (see .env.example) to every target.
-include .env
export

PY  ?= python3.12
DBT  = .venv/bin/dbt
DBT_PROFILES_DIR = .
AIRFLOW_CONSTRAINTS = https://raw.githubusercontent.com/apache/airflow/constraints-3.3.1/constraints-3.12.txt

.NOTPARALLEL:
.PHONY: bootstrap db venv ingest deps build test docs report clean nuke airflow-test

bootstrap: db venv ingest deps build report   ## clean clone -> loaded, built, tested warehouse, report and summary

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

report:   ## one-page HTML reading of the marts, a results summary, and the page in your browser
	@.venv/bin/python report/build_report.py
	@open report/nordstack-billing-report.html 2>/dev/null || xdg-open report/nordstack-billing-report.html 2>/dev/null || true

clean:
	$(DBT) clean

nuke:   ## stop both databases and drop their volumes
	docker compose down -v

airflow-test:   ## parse the DAG in an isolated Airflow install
	test -d airflow/.venv || $(PY) -m venv airflow/.venv
	airflow/.venv/bin/pip install --quiet -r airflow/requirements.txt --constraint $(AIRFLOW_CONSTRAINTS)
	airflow/.venv/bin/pytest airflow/tests -q
