-- One row per customer: lifetime paid revenue, plan mix and status at the cutoff.
with customers as (

    select * from {{ ref('stg_customers') }}

),

subscriptions as (

    select
        customer_id,
        count(*)                                                        as subscriptions_count,
        count(*) filter (where subscription_state = 'active')           as active_subscriptions,
        string_agg(distinct plan_name, ', ' order by plan_name)         as plans_ever,
        string_agg(distinct plan_name, ', ' order by plan_name)
            filter (where subscription_state in ('active', 'pending_cancellation'))
                                                                        as current_plans,
        min(start_date)                                                 as first_subscription_date,
        -- Precedence when a customer holds several subscriptions.
        max(case subscription_state
                when 'active'               then 5
                when 'pending_cancellation' then 4
                when 'paused'               then 3
                when 'pending'              then 2
                when 'cancelled'            then 1
            end)                                                        as status_rank
    from {{ ref('stg_subscriptions') }}
    group by 1

),

revenue as (

    select
        customer_id,
        sum(amount_eur)     as lifetime_paid_eur,
        count(*)            as paid_invoices
    from {{ ref('int_paid_invoices') }}
    group by 1

),

excluded as (

    select customer_id from {{ ref('rej_subscriptions') }}
    union
    select b.customer_id
    from {{ ref('rej_invoices') }} r
    join {{ ref('base_subscriptions') }} b on b.subscription_id = r.subscription_id

)

select
    c.customer_id,
    c.customer_name,
    c.email,
    c.country,
    c.created_at,
    s.first_subscription_date,
    coalesce(s.subscriptions_count, 0)              as subscriptions_count,
    coalesce(s.active_subscriptions, 0)             as active_subscriptions,
    s.plans_ever,
    s.current_plans,
    case s.status_rank
        when 5 then 'active'
        when 4 then 'pending_cancellation'
        when 3 then 'paused'
        when 2 then 'pending'
        when 1 then 'cancelled'
        else 'no_eligible_subscription'
    end                                             as current_status,
    coalesce(r.lifetime_paid_eur, 0)                as lifetime_paid_eur,
    coalesce(r.paid_invoices, 0)                    as paid_invoices,
    e.customer_id is not null                       as has_excluded_records
from customers c
left join subscriptions s on s.customer_id = c.customer_id
left join revenue r       on r.customer_id = c.customer_id
left join excluded e      on e.customer_id = c.customer_id
