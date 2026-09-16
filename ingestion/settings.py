"""Connection settings. Defaults match docker-compose.yml. NORDSTACK_PG_* are the same
variables profiles.yml reads; make exports .env to ingestion and dbt."""
import os

from sqlalchemy import URL


def url(driver: str, prefix: str, defaults: dict) -> str:
    value = lambda key: os.environ.get(f"NORDSTACK_{prefix}_{key}", defaults[key])  # noqa: E731
    return URL.create(
        driver,
        username=value("USER"),
        password=value("PASSWORD"),
        host=value("HOST"),
        port=int(value("PORT")),
        database=value("DB"),
    ).render_as_string(hide_password=False)


MYSQL_URL = url(
    "mysql+pymysql",
    "MYSQL",
    {"USER": "billing_user", "PASSWORD": "billing_password", "HOST": "127.0.0.1", "PORT": "3306", "DB": "billing"},
)
POSTGRES_URL = url(
    "postgresql",
    "PG",
    {"USER": "dbt_user", "PASSWORD": "dbt_password", "HOST": "127.0.0.1", "PORT": "5432", "DB": "analytics"},
)
