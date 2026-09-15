select
    invoice_id,
    subscription_id,
    invoice_date,
    cast(date_trunc('month', invoice_date) as date)     as invoice_month,
    amount,
    currency,
    amount_eur,
    status
from {{ ref('base_invoices') }}
where reject_reason is null
