-- Customers are never rejected: bad contact data does not undo real revenue.
with deduplicated as (

    select distinct customer_id, customer_name, email, country, created_at
    from {{ source('raw', 'raw_customers') }}

),

typed as (

    select
        trim(customer_id)                               as customer_id,
        trim(customer_name)                             as customer_name,
        nullif(trim(email), '')                         as email_raw,
        nullif(upper(trim(country)), '')                as country,
        nullif(trim(created_at), '')                    as created_at_raw,
        cast(nullif(trim(created_at), '') as date)      as created_at_parsed
    from deduplicated

),

first_subscription as (

    select customer_id, min(start_date) as first_start_date
    from {{ ref('base_subscriptions') }}
    group by 1

)

select
    t.customer_id,
    t.customer_name,
    case when t.email_raw ~ '{{ email_regex() }}' then t.email_raw end  as email,
    t.email_raw,
    t.country,
    -- A creation date is trusted only if it is not in the future and not after
    -- the customer's first subscription.
    case
        when t.created_at_parsed <= {{ as_of_date() }}
         and t.created_at_parsed <= coalesce(f.first_start_date, t.created_at_parsed)
        then t.created_at_parsed
    end                                                                 as created_at,
    t.created_at_raw
from typed t
left join first_subscription f on f.customer_id = t.customer_id
