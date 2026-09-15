-- Every month from the earliest subscription or invoice to the cutoff, so monthly
-- marts show zeros rather than gaps.
with bounds as (

    select least(
        (select min(start_date) from {{ ref('stg_subscriptions') }}),
        (select min(invoice_date) from {{ ref('stg_invoices') }})
    ) as first_date

)

select cast(month_start as date) as month_start
from bounds, generate_series(
    cast(date_trunc('month', first_date) as date),
    cast(date_trunc('month', {{ as_of_date() }}) as date),
    interval '1 month'
) as g (month_start)
