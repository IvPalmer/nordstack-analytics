-- Churn totals equal an independent selection from the source: distinct rows,
-- known plan, positive price, cancelled, end between start and the cutoff.
with source_churn as (
    select
        count(*)                                                                    as n,
        coalesce(sum(cast(nullif(trim(monthly_price), '') as numeric(10, 2))), 0)   as lost
    from (
        select distinct subscription_id, customer_id, plan_name, monthly_price, start_date, end_date, status
        from {{ source('raw', 'raw_subscriptions') }}
    ) d
    where lower(trim(status)) = 'cancelled'
      and lower(trim(plan_name)) in ('starter', 'growth', 'scale')
      and cast(nullif(trim(monthly_price), '') as numeric(10, 2)) > 0
      and cast(end_date as date) between cast(start_date as date) and {{ as_of_date() }}
),
mart as (
    select coalesce(sum(churned_subscriptions), 0) as n, coalesce(sum(churned_mrr_eur), 0) as lost
    from {{ ref('fct_churn_monthly') }}
)
select source_churn.n as source_n, mart.n as mart_n, source_churn.lost as source_lost, mart.lost as mart_lost
from source_churn, mart
where source_churn.n <> mart.n or source_churn.lost <> mart.lost
