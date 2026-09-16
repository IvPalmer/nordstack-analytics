"""Render report/nordstack-billing-report.html from the marts in Postgres.

The template holds the layout and the chart code; this script only supplies the
data, so the page is always a faithful reading of the current marts.
"""
import json
import os
import sys
from datetime import date
from pathlib import Path

import psycopg2

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / "template.html"
OUTPUT = HERE / "nordstack-billing-report.html"

CONNECTION = {
    "host": os.environ.get("NORDSTACK_PG_HOST", "127.0.0.1"),
    "port": int(os.environ.get("NORDSTACK_PG_PORT", "5432")),
    "user": os.environ.get("NORDSTACK_PG_USER", "dbt_user"),
    "password": os.environ.get("NORDSTACK_PG_PASSWORD", "dbt_password"),
    "dbname": os.environ.get("NORDSTACK_PG_DB", "analytics"),
}
MARTS = "analytics_marts"
STAGING = "analytics_staging"
QUARANTINE = "analytics_quarantine"

QUERY = f"""
select json_build_object(
  'as_of', (select max(invoice_date) from {STAGING}.stg_invoices),
  'mrr', (select json_agg(json_build_object('m', revenue_month, 'p', plan_name, 'eur', mrr_eur,
                                             'inv', paid_invoices, 'subs', paying_subscriptions)
                          order by revenue_month, plan_name)
          from {MARTS}.fct_mrr_monthly_by_plan),
  'churn', (select json_agg(json_build_object('m', churn_month, 'n', churned_subscriptions, 'eur', churned_mrr_eur)
                            order by churn_month)
            from {MARTS}.fct_churn_monthly),
  'ltv', (select json_agg(json_build_object('id', customer_id, 'name', customer_name, 'country', country,
                                             'status', current_status, 'plans', plans_ever, 'current', current_plans,
                                             'eur', lifetime_paid_eur, 'inv', paid_invoices,
                                             'excl', has_excluded_records, 'first', first_subscription_date)
                          order by lifetime_paid_eur desc)
          from (select * from {MARTS}.dim_customer_ltv order by lifetime_paid_eur desc limit 25) top),
  'status', (select json_object_agg(current_status, n)
             from (select current_status, count(*) as n from {MARTS}.dim_customer_ltv group by 1) s),
  'country', (select json_agg(json_build_object('c', coalesce(country, '??'), 'n', n, 'eur', eur) order by eur desc)
              from (select country, count(*) as n, sum(lifetime_paid_eur) as eur
                    from {MARTS}.dim_customer_ltv group by 1) c),
  'rej', (select json_agg(json_build_object('id', id, 'reason', reason) order by reason, id)
          from (select subscription_id as id, reject_reason as reason from {QUARANTINE}.rej_subscriptions
                union all
                select invoice_id, reject_reason from {QUARANTINE}.rej_invoices) r)
)
"""


def main() -> None:
    with psycopg2.connect(**CONNECTION) as conn, conn.cursor() as cur:
        cur.execute(QUERY)
        data = cur.fetchone()[0]
    html = (
        TEMPLATE.read_text()
        .replace("__DATA__", json.dumps(data, default=str, separators=(",", ":")))
        .replace("__GENERATED__", date.today().strftime("%-d %b %Y"))
    )
    OUTPUT.write_text(html)
    print(f"{OUTPUT.name}: {len(html) // 1024} KB, {len(data['ltv'])} customers listed, cutoff {data['as_of']}")


if __name__ == "__main__":
    sys.exit(main())
