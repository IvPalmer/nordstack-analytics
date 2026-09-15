-- Once a subscription has a trusted end_date, no invoice may be dated after it.
select i.invoice_id, i.subscription_id, i.invoice_date, s.end_date
from {{ ref('stg_invoices') }} i
join {{ ref('stg_subscriptions') }} s on s.subscription_id = i.subscription_id
where i.invoice_date > s.end_date
