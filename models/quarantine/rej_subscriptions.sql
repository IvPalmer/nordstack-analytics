select * from {{ ref('base_subscriptions') }} where reject_reason is not null
