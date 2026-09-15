{% test valid_email(model, column_name) %}
select {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and not ({{ column_name }} ~ '{{ email_regex() }}')
{% endtest %}
