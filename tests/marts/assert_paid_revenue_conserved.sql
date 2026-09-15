-- Every paid euro in the source is in the MRR mart, in the invoice quarantine,
-- or dated after the cutoff. Exact cents.
with source_paid as (
    select coalesce(sum(round(cast(nullif(trim(amount), '') as numeric(12, 2))
                              * {{ fx_rate_to_eur("upper(trim(currency))") }}, 2)), 0) as eur
    from {{ source('raw', 'raw_invoices') }}
    where lower(trim(status)) = 'paid'
),
mart as (
    select coalesce(sum(mrr_eur), 0) as eur from {{ ref('fct_mrr_monthly_by_plan') }}
),
quarantined as (
    select coalesce(sum(amount_eur), 0) as eur from {{ ref('rej_invoices') }} where status = 'paid'
),
after_cutoff as (
    select coalesce(sum(amount_eur), 0) as eur
    from {{ ref('stg_invoices') }}
    where status = 'paid' and invoice_date > {{ as_of_date() }}
)
select source_paid.eur as source_eur, mart.eur as mart_eur, quarantined.eur as quarantined_eur, after_cutoff.eur as after_cutoff_eur
from source_paid, mart, quarantined, after_cutoff
where source_paid.eur <> mart.eur + quarantined.eur + after_cutoff.eur
