-- A customer cannot be created after the cutoff.
{{ config(severity='warn') }}
select customer_id, created_at
from {{ source('raw', 'raw_customers') }}
where cast(created_at as date) > {{ as_of_date() }}
