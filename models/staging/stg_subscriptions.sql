with clean as (

    select * from {{ ref('base_subscriptions') }}
    where reject_reason is null

),

dated as (

    select
        subscription_id,
        customer_id,
        plan_name,
        monthly_price,
        start_date,
        case when end_date_raw >= start_date then end_date_raw end  as end_date,
        end_date_raw,
        status
    from clean

)

select
    *,
    -- State at the cutoff. pending: not started yet. pending_cancellation:
    -- started, cancelled for a date after the cutoff, so still running and billed.
    case
        when start_date > {{ as_of_date() }} and status <> 'cancelled'  then 'pending'
        when status = 'cancelled'
             and start_date <= {{ as_of_date() }}
             and end_date > {{ as_of_date() }}                          then 'pending_cancellation'
        else status
    end                                                                 as subscription_state
from dated
