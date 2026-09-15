-- Customer LTV plus revenue with no customer equals billed MRR.
with ltv as (
    select coalesce(sum(lifetime_paid_eur), 0) as eur from {{ ref('dim_customer_ltv') }}
),
unattributed as (
    select coalesce(sum(p.amount_eur), 0) as eur
    from {{ ref('int_paid_invoices') }} p
    left join {{ ref('stg_customers') }} c on c.customer_id = p.customer_id
    where c.customer_id is null
),
mrr as (
    select coalesce(sum(mrr_eur), 0) as eur from {{ ref('fct_mrr_monthly_by_plan') }}
)
select ltv.eur as ltv_eur, unattributed.eur as unattributed_eur, mrr.eur as mrr_eur
from ltv, unattributed, mrr
where ltv.eur + unattributed.eur <> mrr.eur
