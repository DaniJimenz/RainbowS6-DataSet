{#
    Porcentaje (0-100, 2 decimales) de filas que cumplen una condición booleana.
    Uso: {{ pct_true('has_won') }}  ->  % de victorias
         {{ pct_true('not is_dead') }}  ->  % de supervivencia
#}

{% macro pct_true(condition) -%}
    round(avg(iff({{ condition }}, 1, 0)) * 100, 2)
{%- endmacro %}