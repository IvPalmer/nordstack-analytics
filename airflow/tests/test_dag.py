"""The DAG parses and carries the required configuration."""
import os
from pathlib import Path

os.environ.setdefault("AIRFLOW__CORE__LOAD_EXAMPLES", "False")

from airflow.models import DagBag  # noqa: E402

DAGS_DIR = Path(__file__).resolve().parents[1] / "dags"


def test_dag_loads_and_is_configured():
    bag = DagBag(dag_folder=str(DAGS_DIR))
    assert bag.import_errors == {}, bag.import_errors

    dag = bag.dags["nordstack_billing"]
    assert dag.schedule == "*/5 * * * *"
    assert dag.catchup is False
    assert dag.max_active_runs == 1
    assert dag.on_success_callback is not None
    assert dag.on_failure_callback is not None
    assert [t.task_id for t in dag.tasks] == ["dlt_sync", "dbt_build"]
    assert dag.get_task("dbt_build").upstream_task_ids == {"dlt_sync"}
