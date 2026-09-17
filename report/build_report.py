"""Render report/nordstack-billing-report.html from the warehouse.

The template holds the layout, the chart code and the prose. This script refreshes
headline metrics, charts and row counts from the marts, staging and quarantine
schemas. Diagnostic counts, plan prices and the findings table describe this export
and are written by hand in the template.
"""
import json
import os
import re
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
  'counts', (select json_build_object(
      'raw_c', (select count(*) from raw.raw_customers),
      'raw_s', (select count(*) from raw.raw_subscriptions),
      'raw_i', (select count(*) from raw.raw_invoices),
      'stg_c', (select count(*) from {STAGING}.stg_customers),
      'stg_s', (select count(*) from {STAGING}.stg_subscriptions),
      'stg_i', (select count(*) from {STAGING}.stg_invoices),
      'rej_s', (select count(*) from {QUARANTINE}.rej_subscriptions),
      'rej_i', (select count(*) from {QUARANTINE}.rej_invoices),
      'paid', (select count(*) from {STAGING}.int_paid_invoices),
      'scheduled', (select count(*) from {STAGING}.stg_subscriptions where subscription_state = 'pending_cancellation'),
      'multi', (select count(*) from (
          select customer_id from {STAGING}.stg_subscriptions
          group by 1
          having bool_or(subscription_state = 'active')
             and (array_agg(subscription_state order by start_date desc))[1] <> 'active') m))),
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


def eur(value: float) -> str:
    return f"€{round(value):,}"


def month(iso: str) -> str:
    return date.fromisoformat(str(iso)[:10]).strftime("%B %Y")


def figures(data: dict, cutoff: str) -> dict:
    """Numbers quoted in the prose, all derived from the mart extracts."""
    by_month: dict[str, float] = {}
    subs_by_month: dict[str, int] = {}
    for row in data["mrr"]:
        by_month[row["m"]] = by_month.get(row["m"], 0) + float(row["eur"])
        subs_by_month[row["m"]] = subs_by_month.get(row["m"], 0) + row["subs"]
    months = sorted(by_month)
    last, peak = months[-1], max(months, key=by_month.get)
    revenue = sum(by_month.values())
    scale = sum(float(r["eur"]) for r in data["mrr"] if r["p"] == "scale")
    churn_n = sum(r["n"] for r in data["churn"])
    churn_eur = sum(float(r["eur"]) for r in data["churn"])
    churn_12m = sum(r["n"] for r in data["churn"][-12:])
    top10 = sum(float(r["eur"]) for r in data["ltv"][:10])
    c = data["counts"]
    return {
        "CUTOFF": date.fromisoformat(cutoff).strftime("%-d %b %Y"),
        "MRR_LAST": eur(by_month[last]), "MONTH_LAST": month(last), "SUBS_LAST": subs_by_month[last],
        "MRR_PEAK": eur(by_month[peak]), "MONTH_PEAK": month(peak), "MONTH_FIRST": month(months[0]),
        "SCALE_SHARE": f"{scale / revenue:.0%}",
        "CHURN_N": churn_n, "CHURN_EUR": eur(churn_eur), "CHURN_12M": f"{churn_12m} of the {churn_n}",
        "REVENUE": eur(revenue), "PAID_INVOICES": f"{c['paid']:,}",
        "CUSTOMERS": c["stg_c"], "ACTIVE": data["status"].get("active", 0),
        "TOP10_SHARE": f"{top10 / revenue:.1%}",
        "SCHEDULED": c["scheduled"], "MULTI": c["multi"],
        "RAW_C": c["raw_c"], "RAW_S": c["raw_s"], "RAW_INVOICES": f"{c['raw_i']:,}",
        "RAW_TOTAL": f"{c['raw_c'] + c['raw_s'] + c['raw_i']:,}",
        "COLLAPSED": (c["raw_c"] - c["stg_c"]) + (c["raw_s"] - c["stg_s"] - c["rej_s"]),
        "REJ_S_LABEL": f"{c['rej_s']} subscription{'' if c['rej_s'] == 1 else 's'}", "REJ_INVOICES": c["rej_i"], "REJ_TOTAL": c["rej_s"] + c["rej_i"],
        "STG_C": c["stg_c"], "STG_S": c["stg_s"], "STG_I": f"{c['stg_i']:,}",
        "STG_TOTAL": f"{c['stg_c'] + c['stg_s'] + c['stg_i']:,}",
        "GENERATED": date.today().strftime("%-d %b %Y"),
    }


def cutoff_from_project() -> str:
    import yaml

    project = yaml.safe_load((HERE.parent / "dbt_project.yml").read_text())
    return str(project["vars"]["as_of_date"])


def main() -> None:
    with psycopg2.connect(**CONNECTION) as conn, conn.cursor() as cur:
        cur.execute(QUERY)
        data = cur.fetchone()[0]
    html = TEMPLATE.read_text().replace("__DATA__", json.dumps(data, default=str, separators=(",", ":")))
    for key, value in figures(data, cutoff_from_project()).items():
        html = html.replace(f"__{key}__", str(value))
    assert "__" not in re.sub(r"__dlt_\w+", "", html), "unfilled placeholder in template"
    OUTPUT.write_text(html)
    print(summary(figures(data, cutoff_from_project())))


def hyperlink(uri: str) -> str:
    """OSC 8 terminal hyperlink: clickable in iTerm, Terminal.app, VS Code and Warp."""
    if not sys.stdout.isatty():
        return uri
    return f"\033]8;;{uri}\033\\{uri}\033]8;;\033\\"


def summary(f: dict) -> str:
    """Results block printed at the end of make bootstrap and make report."""
    run_results = HERE.parent / "target" / "run_results.json"
    dbt_line = "run make build for test results"
    if run_results.exists():
        results = json.loads(run_results.read_text())
        if results.get("args", {}).get("which") == "build":
            statuses = [r["status"] for r in results["results"]]
            passed = statuses.count("pass") + statuses.count("success")
            warned, failed = statuses.count("warn"), statuses.count("error") + statuses.count("fail")
            dbt_line = f"PASS={passed} WARN={warned} ERROR={failed}"
            if warned and not failed:
                dbt_line += "  (warnings are source diagnostics, one per defect in the export, meant to warn)"
    rows = [
        ("dbt build", dbt_line),
        ("Billed revenue", f"{f['REVENUE']} over {f['PAID_INVOICES']} paid invoices"),
        (f"MRR {f['MONTH_LAST']}", f"{f['MRR_LAST']} across {f['SUBS_LAST']} paying subscriptions"),
        ("Customers", f"{f['CUSTOMERS']}, {f['ACTIVE']} active at the cutoff"),
        ("Churn", f"{f['CHURN_N']} subscriptions, {f['CHURN_EUR']} contractual MRR"),
        ("Quarantined", f"{f['REJ_TOTAL']} rows ({f['REJ_S_LABEL']}, {f['REJ_INVOICES']} invoices)"),
        ("Report", hyperlink(OUTPUT.as_uri())),
        ("Open it", "make open"),
        ("Docs", "make docs"),
    ]
    width = max(len(k) for k, _ in rows)
    lines = "\n".join(f"  {k.ljust(width)}  {v}" for k, v in rows)
    return f"\nNordStack analytics, reporting cutoff {f['CUTOFF']}\n{lines}\n"


if __name__ == "__main__":
    sys.exit(main())
