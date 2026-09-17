# NordStack billing analytics

dbt analytics layer over three raw billing exports (customers, subscriptions, invoices),
with the optional dlt step and an Airflow DAG.

## Setup

Requirements: Docker Desktop (Compose v2), Python 3.12, make.

    git clone https://github.com/IvPalmer/nordstack-analytics.git
    cd nordstack-analytics
    make bootstrap

`make bootstrap` starts MySQL and Postgres, loads the CSVs into MySQL, syncs them to
Postgres with dlt, installs dbt, runs `dbt build` and prints a summary. First run takes a
few minutes. Expected end: `PASS=100 WARN=17 ERROR=0`. The 17 warnings are the
source-level checks that catch the planted issues; they warn by design and the marts
downstream pass.

If port 5432 or 3306 is in use, copy `.env.example` to `.env` and change the port.

Other targets: `make docs` (dbt docs), `make airflow-test` (parse the DAG in an isolated
Airflow 3.3), `make build` (dbt only), `make nuke` (drop both databases).

## Project structure

    data/*.csv  ->  MySQL  ->  dlt  ->  Postgres raw  ->  dbt staging / quarantine  ->  marts

    data/                 the three CSV exports, unchanged
    ingestion/            load_source_system.py (CSV -> MySQL), sync_to_warehouse.py (dlt MySQL -> Postgres)
    models/sources.yml    raw tables, 28 warn-level checks
    models/staging/       base_* type and classify each row; stg_* keep the usable rows
    models/quarantine/    rej_* keep the rejected rows with a reject_reason
    models/intermediate/  paid invoices in EUR within the cutoff, month spine
    models/marts/         fct_mrr_monthly_by_plan, dim_customer_ltv, fct_churn_monthly
    tests/                singular tests: source diagnostics (warn), disposition, business rules, reconciliation, coverage (error)
    airflow/              nordstack_billing DAG, parse test, deploy notes
    report/               one-page HTML report (optional extra)

Staging, quarantine and intermediate are views; marts are tables.

## Modeling decisions

- **Typing.** Columns arrive as text and are cast once in `base_*`. Empty cells are NULL.
  A malformed date or amount stops the build rather than being quarantined.
- **Invalid values.** When a value fails a rule the clean column is NULL and a `_raw`
  column keeps the export value (`email`, `created_at`, `end_date`). No flag columns.
- **Rejected rows.** `base_*` assigns a `reject_reason` (non-positive price or
  amount, missing amount or start date, unknown plan, status, currency or subscription).
  `stg_*` keeps the rest, `rej_*` the rejected rows; tests prove clean + rejected = raw.
  Kept on purpose: a subscription with no customer record (its paid invoices count in MRR,
  not in LTV) and a subscription whose end date precedes its start (invoices count, end
  date nulled, never churn).
- **MRR.** Sum of paid invoice amounts in EUR by invoice month and plan. FX is a var, `fx_rates_to_eur` (EUR 1.0, SEK 0.087); other currencies are
  rejected.
- **Churn.** Cancelled subscriptions by month of end date; lost MRR is the sum of
  `monthly_price`, assumed EUR since the export has no currency on subscriptions.
- **Reporting cutoff.** `as_of_date` = 2026-07-28, the last invoice date. Subscriptions
  starting later are `pending`; cancelled for a later date are `pending_cancellation`
  and still billing. A customer's status is the strongest across their subscriptions.
- **Ingestion.** dlt `sql_database` with `write_disposition="replace"`: the source has no
  change tracking and the tables are small.

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

Also observed: paused subscriptions keep being invoiced, and 14 customers have an older
active subscription next to a newer inactive one, which is why status is aggregated.

Tests: source checks are WARN and document the export; everything after staging is ERROR.
Singular tests cover disposition (clean + rejected = raw), the billing rule (no invoice
after a trusted cancellation), reconciliation of paid revenue, LTV and churn to the
source, and grid coverage of the monthly marts. Four dbt unit tests pin the subscription
state, customer status, churn and MRR rules. Reconciliation: €325,086.01 paid in the
source = €325,282.01 in the marts + (-€196.00) quarantined.

## Airflow

`airflow/dags/nordstack_billing.py`: `dlt_sync >> dbt_build` every five minutes, email on
success and on failure. Deployment notes in [`airflow/README.md`](airflow/README.md).

## Optional extensions

Not required by the assessment; where the project would go next in production.

- Incremental dlt loads once the source exposes an updated-at column or CDC.
- dbt snapshots on subscriptions for status history and contractual MRR.
- CI with `dbt build --select state:modified+` against a production manifest.
- FX from a rates table; dbt-expectations for distribution checks.

## One-page report (optional extra)

`make report` renders [`report/nordstack-billing-report.html`](report/nordstack-billing-report.html)
from the marts: a single file with inline SVG charts, printable.

<img src="docs/report.png" width="640" alt="Top of the one-page report">
