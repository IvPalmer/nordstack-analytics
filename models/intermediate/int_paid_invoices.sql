-- Paid invoices inside the reporting window, with plan and customer.
-- Shared by MRR and LTV so both count exactly the same revenue rows.
select
    i.invoice_id,
    i.subscription_id,
    s.customer_id,
    s.plan_name,
    i.invoice_date,
    i.invoice_month,
    i.amount_eur
from {{ ref('stg_invoices') }} i
join {{ ref('stg_subscriptions') }} s on s.subscription_id = i.subscription_id
where i.status = 'paid'
  and i.invoice_date <= {{ as_of_date() }}
