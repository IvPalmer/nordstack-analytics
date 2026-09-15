-- Nothing is invoiced after a cancellation date.
{{ config(severity='warn') }}
select i.invoice_id, i.subscription_id, i.invoice_date, s.end_date
from {{ source('raw', 'raw_invoices') }} i
join {{ source('raw', 'raw_subscriptions') }} s on s.subscription_id = i.subscription_id
where cast(i.invoice_date as date) > cast(s.end_date as date)
