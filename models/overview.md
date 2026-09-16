{% docs __overview__ %}
# NordStack billing analytics

Billing exports -> MySQL (source system) -> dlt -> Postgres `raw` -> this project.

- `raw` sources carry warn-level diagnostics, one per defect in the export.
- `base_*` types and classifies every row; `stg_*` keeps the usable ones, `rej_*` the rest with a `reject_reason`.
- `int_*` holds paid invoices in EUR within the cutoff and the month spine.
- Marts: `fct_mrr_monthly_by_plan`, `dim_customer_ltv`, `fct_churn_monthly`.

Reporting cutoff and FX rates are project vars (`as_of_date`, `fx_rates_to_eur`).
{% enddocs %}
