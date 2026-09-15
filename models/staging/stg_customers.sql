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

)

select
    customer_id,
    customer_name,
    case when email_raw ~ '{{ email_regex() }}' then email_raw end                  as email,
    email_raw,
    country,
    case when created_at_parsed <= {{ as_of_date() }} then created_at_parsed end    as created_at,
    created_at_raw
from typed
