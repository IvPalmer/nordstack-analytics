{% docs __overview__ %}
# NordStack billing analytics

Billing exports -> MySQL (source system) -> dlt -> Postgres `raw` -> this project.

- `raw` sources carry 28 warn-level checks; 17 fail on this export and are meant to.
- `base_*` types and classifies subscriptions and invoices; `stg_*` keeps the usable rows, `rej_*` the rest with a `reject_reason`. Customers are typed in `stg_customers` and never rejected.
- `int_*` holds paid invoices in EUR within the cutoff and the month spine.
- Marts: `fct_mrr_monthly_by_plan`, `dim_customer_ltv`, `fct_churn_monthly`.

Reporting cutoff and FX rates are project vars (`as_of_date`, `fx_rates_to_eur`).
{% enddocs %}
