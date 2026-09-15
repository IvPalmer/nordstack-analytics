# Airflow

`dags/nordstack_billing.py`: `dlt_sync >> dbt_build` every 5 minutes, email on success
and on failure through DAG-level callbacks (SMTP provider).

Environment for the DAG processor and the workers (the DAG reads these at parse time,
the tasks at run time):

- this repository at `NORDSTACK_PROJECT_DIR`, with its venv's `python` and `dbt` as
  `NORDSTACK_PYTHON` / `NORDSTACK_DBT`, and `dbt deps` run at deploy time;
- databases reachable through the `NORDSTACK_*` connection variables (see `.env.example`);
- an Airflow connection `smtp_default` (or `NORDSTACK_SMTP_CONN_ID`) with host, port,
  login, password and the extra `{"from_email": "..."}`, which the SMTP notifier requires;
- recipients in `NORDSTACK_ALERT_EMAILS`, comma separated.

Validate the DAG without a scheduler:

    make airflow-test
