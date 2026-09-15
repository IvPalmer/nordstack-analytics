-- Billed MRR: paid invoice amounts in EUR by invoice month and plan.
with grid as (

    select m.month_start, p.plan_name
    from {{ ref('int_month_spine') }} m
    cross join (select distinct plan_name from {{ ref('stg_subscriptions') }}) p

),

paid as (

    select
        invoice_month,
        plan_name,
        sum(amount_eur)                     as mrr_eur,
        count(*)                            as paid_invoices,
        count(distinct subscription_id)     as paying_subscriptions
    from {{ ref('int_paid_invoices') }}
    group by 1, 2

)

select
    grid.month_start                        as revenue_month,
    grid.plan_name,
    coalesce(paid.mrr_eur, 0)               as mrr_eur,
    coalesce(paid.paid_invoices, 0)         as paid_invoices,
    coalesce(paid.paying_subscriptions, 0)  as paying_subscriptions
from grid
left join paid
    on paid.invoice_month = grid.month_start
   and paid.plan_name = grid.plan_name
