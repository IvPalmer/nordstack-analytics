{#- CASE expression from vars.fx_rates_to_eur; NULL for an unknown currency. -#}
{% macro fx_rate_to_eur(currency) -%}
    case {{ currency }}
    {%- for code, rate in var('fx_rates_to_eur').items() %}
        when '{{ code }}' then {{ rate }}
    {%- endfor %}
    end
{%- endmacro %}
