-- A full-replace load that delivered nothing must not produce a green, empty warehouse.
select 'raw_customers' as source_table
where not exists (select 1 from {{ source('raw', 'raw_customers') }})
union all
select 'raw_subscriptions'
where not exists (select 1 from {{ source('raw', 'raw_subscriptions') }})
union all
select 'raw_invoices'
where not exists (select 1 from {{ source('raw', 'raw_invoices') }})
