-- Every month from the first invoice to the cutoff, so monthly marts show zeros
-- rather than gaps.
select cast(month_start as date) as month_start
from generate_series(
    (select cast(date_trunc('month', min(invoice_date)) as date) from {{ ref('stg_invoices') }}),
    cast(date_trunc('month', {{ as_of_date() }}) as date),
    interval '1 month'
) as g (month_start)
