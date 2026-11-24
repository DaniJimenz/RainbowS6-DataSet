{#
    Margen (en puntos) que tiene que superar la diferencia frente a la referencia
    para considerarla desequilibrio. Es el mayor de:
      - balance_threshold_pp: diferencia mínima para que importe en la práctica
      - 1.96 errores estándar de una proporción con n observaciones: diferencia
        estadísticamente significativa al 95 % (no explicable por azar)
    Uso: {{ balance_margin_pp('role_win_rate_pct', 'player_rounds') }}
#}

{% macro balance_margin_pp(benchmark_pct, n) -%}
    greatest(
          {{ var('balance_threshold_pp') }}
        , 1.96 * 100 * sqrt(({{ benchmark_pct }} / 100) * (1 - {{ benchmark_pct }} / 100) / {{ n }})
    )
{%- endmacro %}