# NordStack billing analytics

Three raw billing exports, rebuilt as a tested analytics layer: MySQL as the source
system, dlt into Postgres, dbt models and tests, an Airflow DAG every five minutes, and a
one-page report read from the marts.

## Results

| | |
|---|---|
| Billed revenue to date | €325,282 over 2,445 paid invoices (Jan 2024 to Jul 2026) |
| MRR, July 2026 | €14,003 across 107 paying subscriptions; peak €15,484 in Dec 2025 |
| Customers | 120, of which 86 active at the cutoff |
| Churn | 46 subscriptions, €7,114 of contractual MRR |
| Data quality | 28 warn-level checks on the raw tables, 17 fail on this export; 10 rows quarantined, 2 duplicates collapsed |
| Reconciliation | €325,086.01 paid in the source = €325,282.01 in the marts + (-€196.00) quarantined paid amounts |

![Top of the one-page report: headline figures and billed MRR by plan](docs/report.png)

Full page: [`report/nordstack-billing-report.html`](report/nordstack-billing-report.html).
Marts are in schema `analytics_marts`, for example:

    select revenue_month, plan_name, mrr_eur
    from analytics_marts.fct_mrr_monthly_by_plan
    where revenue_month >= date '2026-01-01'
    order by 1, 2;

## Run it

Requirements: Docker Desktop (Compose v2), Python 3.12, make.

    git clone https://github.com/IvPalmer/nordstack-analytics.git
    cd nordstack-analytics
    make bootstrap

That starts MySQL and Postgres, loads the CSVs, syncs them with dlt, installs dbt, runs
`dbt build` and renders the report. It takes a few minutes the first time and ends with
a results summary and the path of the report. Expect `ERROR=0` and 17 warnings: they are
the source checks listed under findings, which are meant to warn.

If port 5432 or 3306 is already in use, copy `.env.example` to `.env` and change the
port there before running.

Other targets: `make docs` (dbt documentation and lineage), `make report` (rebuild the
report), `make airflow-test` (parse the DAG in an isolated Airflow 3.3), `make build`
(dbt only), `make nuke` (remove both databases).

## How it is built

    data/*.csv  ->  MySQL (billing)  ->  dlt  ->  Postgres raw  ->  dbt  ->  marts  ->  report

    data/                 billing CSV exports, unchanged
    ingestion/            CSV -> MySQL, then dlt MySQL -> Postgres
    models/sources.yml    raw tables with warn-level checks
    models/staging/       base_* type and classify; stg_* keep the usable rows
    models/quarantine/    rej_* keep the rejected rows with a reject_reason
    models/intermediate/  paid invoices in EUR within the cutoff, month spine
    models/marts/         fct_mrr_monthly_by_plan, dim_customer_ltv, fct_churn_monthly
    tests/                source diagnostics (warn); disposition, business-rule, reconciliation and coverage tests (error)
    report/               template and builder for the one-page report
    airflow/              DAG, parse test, deploy notes

## Decisions

- **Ingestion.** dlt `sql_database` with `write_disposition="replace"`: no change tracking
  in the source and small tables, so a full reload is appropriate.
- **Raw stays raw.** Columns arrive as text and are cast once in `base_*` (customers in
  `stg_customers`, since they are never rejected). Empty cells are NULL. A malformed date
  or amount stops the build rather than being quarantined.
- **Clean column plus `_raw` column.** When a value fails a rule the clean column is NULL
  and `_raw` keeps the export value (`email`, `created_at`, `end_date`).
- **Quarantine, not deletion.** `base_*` assigns a `reject_reason` (non-positive price or
  amount, missing amount or start date, unknown plan, status, currency or subscription).
  Tests prove clean + rejected = raw. Two defects are kept on purpose: a subscription with
  no customer record (paid invoices count in MRR, not in LTV) and a subscription whose end
  date precedes its start (invoices count; end date nulled; never counted as churn).
- **Views before marts, tables for marts.**
- **MRR is billed, churn loss is contractual.** MRR sums paid invoices in EUR by invoice
  month, as the brief asks. Churn sums `monthly_price` of subscriptions cancelled in the
  month. The two bases differ on purpose.
- **Fixed cutoff.** `as_of_date` = 2026-07-28, the last invoice date, instead of
  `current_date`. It defines `pending` (not cancelled, starts later) and
  `pending_cancellation` (cancelled for a later date, still billing). A customer's status
  is the strongest across their subscriptions: active, pending_cancellation, paused,
  pending, cancelled.
- **Currency.** Two SEK invoices converted with `fx_rates_to_eur`; any other currency is
  rejected. `monthly_price` has no currency in the export and is assumed EUR.
- **Billing rule.** No invoice may be dated after a trusted cancellation date.

## Data-quality findings

| # | Issue | Record | Caught by | Handling |
|---|---|---|---|---|
| 1 | Duplicate customer row | C0023 | unique | collapsed |
| 2 | Invalid email | C0016 | valid_email | email NULL, email_raw kept |
| 3 | Missing country | C0008 | not_null | NULL |
| 4 | Created in the future, after its own subscription | C0041 / S00054 | two singular tests | created_at NULL, created_at_raw kept |
| 5 | Duplicate subscription row | S00006 | unique | collapsed |
| 6 | Subscription with unknown customer | S00011 -> C9999 | relationships | kept; revenue in MRR, absent from LTV |
| 7 | Upper-case status | S00026 | accepted_values | lower-cased |
| 8 | Negative price and 7 negative invoices | S00048 | expression_is_true | subscription and invoices quarantined |
| 9 | End date before start date, 17 invoices after it | S00034 | singular tests | end_date NULL; invoices kept; never churn |
| 10 | Starts after the cutoff | S00149 | singular test | state pending |
| 11 | Cancelled for a date after the cutoff | S00020, S00070, S00139, S00167 | singular test | state pending_cancellation; not churn |
| 12 | Invoice with unknown subscription | I000601 -> S99999 | relationships | quarantined |
| 13 | Paid invoice with no amount | I000322 | not_null | quarantined |
| 14 | Status with trailing space and upper case | I000451 | accepted_values | trimmed, lower-cased |
| 15 | Two SEK invoices | I000101, I000201 | accepted_values | converted at the var rate |

Not defects, but relevant: paused subscriptions keep being invoiced, and for 14 customers
the newest subscription is not the active one, which is why status is aggregated rather
than read from the latest row.

## Tests

- Source checks are WARN and stay that way: they document the export. Handling lives in
  `base_*` and `stg_*`.
- Disposition tests: clean + rejected = raw (distinct raw rows for subscriptions).
- Reconciliation tests tie paid revenue, LTV and churn back to the source, to the cent.
- Coverage tests: one MRR row per month and plan, one churn row per month, one LTV row per
  customer.
- dbt unit tests on the rules with the most branches: subscription state at the cutoff,
  customer status and revenue attribution, churn by month, MRR by month and plan.
- Everything after staging is ERROR.

## Airflow

`airflow/dags/nordstack_billing.py` runs `dlt_sync >> dbt_build` every five minutes with
email on success and on failure. Deployment notes and the parse test:
[`airflow/README.md`](airflow/README.md).

## Report

`make report` renders the one-page HTML from the warehouse: embedded data, inline SVG
charts with hover detail and data tables, printable to PDF. `report/template.html` holds
layout, charts and prose; `report/build_report.py` fills the figures. The findings table
and plan prices describe this export and are written by hand.

## Validation

| Check | Command | Outcome |
|---|---|---|
| Clean-clone build | `make bootstrap` | `PASS=100 WARN=17 ERROR=0` (dbt-core 1.11.15, dbt-postgres 1.11.0, dlt 1.30.0, Postgres 16, MySQL 8.4) |
| DAG parse | `make airflow-test` | 1 passed (apache-airflow 3.3.1) |
| Marts vs an independent replica | pandas over `data/*.csv` with the documented rules | MRR 325,282.01; LTV 322,890.01; churn 46 / 7,114.00 |

## Limitations

- The cutoff is 2026-07-28, so July 2026 holds 28 days of invoices.
- €2,392 of paid revenue belongs to a subscription with no customer record: in MRR, in
  nobody's lifetime value.
- One paid invoice has no amount; it is quarantined and counted, not valued.
- SEK at a fixed 0.087; `monthly_price` assumed EUR.
- Email delivery from the DAG is configured, not exercised.

## Next steps

- Incremental dlt loads once the source exposes an updated-at column or CDC.
- dbt snapshots on subscriptions for status history and contractual MRR.
- CI with `dbt build --select state:modified+` against a production manifest.
- FX from a rates table; dbt-expectations for distribution checks.
