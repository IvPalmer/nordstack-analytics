-- Starts or ends after the cutoff are not events yet.
{{ config(severity='warn') }}
select subscription_id, start_date, end_date, status
from {{ source('raw', 'raw_subscriptions') }}
where cast(start_date as date) > {{ as_of_date() }}
   or cast(end_date as date) > {{ as_of_date() }}
