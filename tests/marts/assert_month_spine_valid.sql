-- The spine is exactly every month-start from the first invoice month to the cutoff month.
with bounds as (
    select
        cast(date_trunc('month', min(invoice_date)) as date)    as first_month,
        cast(date_trunc('month', {{ as_of_date() }}) as date)  as last_month
    from {{ ref('stg_invoices') }}
),
expected as (
    select cast(g as date) as month_start
    from bounds, generate_series(bounds.first_month, bounds.last_month, interval '1 month') as g
),
actual as (
    select month_start from {{ ref('int_month_spine') }}
)
select 'missing' as problem, * from (select * from expected except all select * from actual) t
union all
select 'extra' as problem, * from (select * from actual except all select * from expected) t
