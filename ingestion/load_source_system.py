"""Load the billing CSV exports into MySQL, standing in for the source system."""
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine

from settings import MYSQL_URL

DATA_DIR = Path(__file__).resolve().parents[1] / "data"


def main() -> None:
    engine = create_engine(MYSQL_URL)
    for csv_path in sorted(DATA_DIR.glob("raw_*.csv")):
        # Empty CSV cells are loaded as SQL NULL.
        frame = pd.read_csv(csv_path, dtype=str, keep_default_na=False).replace("", None)
        frame.to_sql(csv_path.stem, engine, if_exists="replace", index=False)
        print(f"{csv_path.stem}: {len(frame)} rows")


if __name__ == "__main__":
    main()
