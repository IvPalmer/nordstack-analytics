-- A customer exists before their first subscription starts.
{{ config(severity='warn') }}
select s.customer_id, c.created_at, min(s.start_date) as first_subscription_start
from {{ source('raw', 'raw_subscriptions') }} s
join {{ source('raw', 'raw_customers') }} c on c.customer_id = s.customer_id
group by s.customer_id, c.created_at
having min(cast(s.start_date as date)) < cast(c.created_at as date)
