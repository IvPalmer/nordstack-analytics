{% macro as_of_date() -%}
    cast('{{ var("as_of_date") }}' as date)
{%- endmacro %}
