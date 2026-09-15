select * from {{ ref('base_invoices') }} where reject_reason is not null
