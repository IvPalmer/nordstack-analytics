-- Each raw invoice is in exactly one of stg / rej, never both.
with raw_ids as (
    select trim(invoice_id) as id from {{ source('raw', 'raw_invoices') }}
),
disposed as (
    select invoice_id as id from {{ ref('stg_invoices') }}
    union all
    select invoice_id as id from {{ ref('rej_invoices') }}
)
select 'missing' as problem, id from (select * from raw_ids except all select * from disposed) t
union all
select 'extra' as problem, id from (select * from disposed except all select * from raw_ids) t
union all
select 'both' as problem, s.invoice_id
from {{ ref('stg_invoices') }} s
join {{ ref('rej_invoices') }} r on r.invoice_id = s.invoice_id
