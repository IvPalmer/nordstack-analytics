-- end_date is null or on/after start_date.
{{ config(severity='warn') }}
select subscription_id, start_date, end_date
from {{ source('raw', 'raw_subscriptions') }}
where cast(end_date as date) < cast(start_date as date)
