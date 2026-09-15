"""Sync the billing tables from MySQL to the Postgres warehouse with dlt."""
import dlt
from dlt.sources.sql_database import sql_database

from settings import MYSQL_URL, POSTGRES_URL

TABLES = ["raw_customers", "raw_subscriptions", "raw_invoices"]


def main() -> None:
    pipeline = dlt.pipeline(
        pipeline_name="nordstack_billing",
        destination=dlt.destinations.postgres(POSTGRES_URL),
        dataset_name="raw",
    )
    # replace = truncate and reload: the source has no change tracking and the
    # tables are small. dbt views on top survive a truncate.
    info = pipeline.run(sql_database(MYSQL_URL, table_names=TABLES), write_disposition="replace")
    print(info)


if __name__ == "__main__":
    main()
