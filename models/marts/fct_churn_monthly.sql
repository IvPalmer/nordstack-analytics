-- Realised churn: subscriptions whose trusted end_date falls in the month, on or
-- before the cutoff. Lost MRR is contractual (monthly_price), not billed.
with churned as (

    select
        cast(date_trunc('month', end_date) as date)     as churn_month,
        count(*)                                        as churned_subscriptions,
        sum(monthly_price)                              as churned_mrr_eur
    from {{ ref('stg_subscriptions') }}
    where status = 'cancelled'
      and end_date <= {{ as_of_date() }}
    group by 1

)

select
    m.month_start                               as churn_month,
    coalesce(c.churned_subscriptions, 0)        as churned_subscriptions,
    coalesce(c.churned_mrr_eur, 0)              as churned_mrr_eur
from {{ ref('int_month_spine') }} m
left join churned c on c.churn_month = m.month_start
