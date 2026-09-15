with typed as (

    select
        trim(invoice_id)                                    as invoice_id,
        trim(subscription_id)                               as subscription_id,
        cast(nullif(trim(invoice_date), '') as date)        as invoice_date,
        cast(nullif(trim(amount), '') as numeric(12, 2))    as amount,
        upper(trim(currency))                               as currency,
        lower(trim(status))                                 as status
    from {{ source('raw', 'raw_invoices') }}

),

classified as (

    select
        typed.*,
        {{ fx_rate_to_eur('typed.currency') }}              as fx_rate_to_eur,
        case
            when typed.invoice_date is null                     then 'missing_invoice_date'
            when typed.amount is null                           then 'missing_amount'
            when typed.amount <= 0                              then 'non_positive_amount'
            when {{ fx_rate_to_eur('typed.currency') }} is null then 'unsupported_currency'
            when typed.status not in ('paid', 'failed', 'open') then 'unknown_status'
            when sub.subscription_id is null                    then 'unknown_subscription'
            when sub.reject_reason is not null                  then 'rejected_subscription'
        end                                                 as reject_reason
    from typed
    left join {{ ref('base_subscriptions') }} sub on sub.subscription_id = typed.subscription_id

)

select
    *,
    round(amount * fx_rate_to_eur, 2)                       as amount_eur
from classified
