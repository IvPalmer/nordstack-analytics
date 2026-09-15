"""Sync billing data from MySQL and rebuild the dbt project every 5 minutes.

Emails are DAG-level callbacks so they report the terminal state of each run.
No retries: at a 5-minute cadence the next run is the retry, and max_active_runs=1
with timeouts keeps a hung run from stacking.
"""
from __future__ import annotations

import os
import shlex
from datetime import timedelta

import pendulum
from airflow.providers.smtp.notifications.smtp import send_smtp_notification
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

PROJECT_DIR = os.environ.get("NORDSTACK_PROJECT_DIR", "/opt/airflow/nordstack-analytics")
PYTHON = os.environ.get("NORDSTACK_PYTHON", "python")
DBT = os.environ.get("NORDSTACK_DBT", "dbt")
ALERT_EMAILS = [a.strip() for a in os.environ.get("NORDSTACK_ALERT_EMAILS", "data-alerts@example.com").split(",") if a.strip()]


def notify(outcome: str):
    # Only dag, run_id and reason are guaranteed in a DAG-level callback context.
    return send_smtp_notification(
        smtp_conn_id=os.environ.get("NORDSTACK_SMTP_CONN_ID", "smtp_default"),
        to=ALERT_EMAILS,
        subject=f"[nordstack] billing pipeline {outcome}: {{{{ run_id }}}}",
        html_content=f"<p>Pipeline <b>{outcome}</b>. Run {{{{ run_id }}}}. {{{{ reason | default('') }}}}</p>",
    )


with DAG(
    dag_id="nordstack_billing",
    description="MySQL -> dlt -> Postgres -> dbt build, every 5 minutes",
    schedule="*/5 * * * *",
    start_date=pendulum.datetime(2026, 9, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    dagrun_timeout=timedelta(minutes=4, seconds=30),
    default_args={"owner": "data-platform", "retries": 0, "execution_timeout": timedelta(minutes=2)},
    on_success_callback=notify("succeeded"),
    on_failure_callback=notify("failed"),
    tags=["billing", "dbt", "dlt"],
) as dag:
    sync = BashOperator(
        task_id="dlt_sync",
        cwd=PROJECT_DIR,
        bash_command=f"{shlex.quote(PYTHON)} ingestion/sync_to_warehouse.py",
    )
    build = BashOperator(
        task_id="dbt_build",
        cwd=PROJECT_DIR,
        bash_command=f"{shlex.quote(DBT)} build --profiles-dir . --no-use-colors",
    )

    sync >> build
