"""Load the billing CSV exports into MySQL, standing in for the source system."""
import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine

DATA_DIR = Path(__file__).resolve().parents[1] / "data"
MYSQL_URL = os.environ.get(
    "NORDSTACK_MYSQL_URL",
    "mysql+pymysql://billing_user:billing_password@127.0.0.1:3306/billing",
)


def main() -> None:
    engine = create_engine(MYSQL_URL)
    for csv_path in sorted(DATA_DIR.glob("raw_*.csv")):
        # Blank cells become NULL, as the source database would store them.
        frame = pd.read_csv(csv_path, dtype=str, keep_default_na=False).replace("", None)
        frame.to_sql(csv_path.stem, engine, if_exists="replace", index=False)
        print(f"{csv_path.stem}: {len(frame)} rows")


if __name__ == "__main__":
    main()
