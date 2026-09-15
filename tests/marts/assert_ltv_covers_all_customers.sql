-- Exactly one LTV row per customer.
select 'missing' as problem, customer_id
from (select customer_id from {{ ref('stg_customers') }}
      except all
      select customer_id from {{ ref('dim_customer_ltv') }}) t
union all
select 'extra' as problem, customer_id
from (select customer_id from {{ ref('dim_customer_ltv') }}
      except all
      select customer_id from {{ ref('stg_customers') }}) t
