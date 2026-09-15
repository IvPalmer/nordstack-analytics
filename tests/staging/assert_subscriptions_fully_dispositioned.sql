-- Each distinct raw subscription is in exactly one of stg / rej, never both.
-- Explicit columns: dlt adds a per-row _dlt_id, so distinct * would not collapse duplicates.
with raw_ids as (
    select trim(subscription_id) as id
    from (
        select distinct subscription_id, customer_id, plan_name, monthly_price, start_date, end_date, status
        from {{ source('raw', 'raw_subscriptions') }}
    ) d
),
disposed as (
    select subscription_id as id from {{ ref('stg_subscriptions') }}
    union all
    select subscription_id as id from {{ ref('rej_subscriptions') }}
)
select 'missing' as problem, id from (select * from raw_ids except all select * from disposed) t
union all
select 'extra' as problem, id from (select * from disposed except all select * from raw_ids) t
union all
select 'both' as problem, s.subscription_id
from {{ ref('stg_subscriptions') }} s
join {{ ref('rej_subscriptions') }} r on r.subscription_id = s.subscription_id
