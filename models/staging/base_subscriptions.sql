with deduplicated as (

    select distinct subscription_id, customer_id, plan_name, monthly_price, start_date, end_date, status
    from {{ source('raw', 'raw_subscriptions') }}

),

typed as (

    select
        trim(subscription_id)                                       as subscription_id,
        trim(customer_id)                                           as customer_id,
        lower(trim(plan_name))                                      as plan_name,
        cast(nullif(trim(monthly_price), '') as numeric(10, 2))     as monthly_price,
        cast(nullif(trim(start_date), '') as date)                  as start_date,
        cast(nullif(trim(end_date), '') as date)                    as end_date_raw,
        lower(trim(status))                                         as status
    from deduplicated

)

select
    *,
    -- First matching rule wins. A missing customer or an inverted date range is
    -- not a reason to reject: the invoices are real money. Those cases are kept,
    -- with end_date nulled in stg_subscriptions and no customer attribution in LTV.
    case
        when plan_name not in ('starter', 'growth', 'scale')    then 'unknown_plan'
        when monthly_price is null or monthly_price <= 0        then 'non_positive_price'
        when start_date is null                                 then 'missing_start_date'
        when status not in ('active', 'paused', 'cancelled')    then 'unknown_status'
    end                                                         as reject_reason
from typed
