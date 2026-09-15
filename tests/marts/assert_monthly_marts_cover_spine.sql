-- MRR keys are exactly spine months x plans; churn keys are exactly the spine months.
with mrr_expected as (
    select m.month_start, p.plan_name
    from {{ ref('int_month_spine') }} m
    cross join (select distinct plan_name from {{ ref('stg_subscriptions') }}) p
),
mrr_actual as (
    select revenue_month, plan_name from {{ ref('fct_mrr_monthly_by_plan') }}
),
churn_expected as (
    select month_start from {{ ref('int_month_spine') }}
),
churn_actual as (
    select churn_month from {{ ref('fct_churn_monthly') }}
)
select 'mrr_missing' as problem, cast(month_start as text) || ' ' || plan_name as key
from (select * from mrr_expected except all select * from mrr_actual) t
union all
select 'mrr_extra', cast(revenue_month as text) || ' ' || plan_name
from (select * from mrr_actual except all select * from mrr_expected) t
union all
select 'churn_missing', cast(month_start as text)
from (select * from churn_expected except all select * from churn_actual) t
union all
select 'churn_extra', cast(churn_month as text)
from (select * from churn_actual except all select * from churn_expected) t
