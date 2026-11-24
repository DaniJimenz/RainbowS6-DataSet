{%- set min_rounds = var('min_rounds_for_map_balance') -%}

with rounds as (

    select * from {{ ref('fct_rounds') }}

),

objectives as (

    select * from {{ ref('dim_objectives') }}

),

joined as (

    select
          o.map_name
        , o.game_mode
        , o.objective_location
        , r.is_attacker_win
        , r.round_duration_seconds
        , r.is_valid_duration
        -- Referencia de cada ronda: % de victorias del ataque en su modo de juego.
        -- El modo pesa mucho (HOSTAGE favorece a la defensa), así se aísla el efecto del mapa.
        , avg(iff(r.is_attacker_win, 1, 0)) over (partition by o.game_mode) * 100
                                                              as mode_attacker_win_rate_pct
    from rounds r
    inner join objectives o on r.objective_key = o.objective_key

),

aggregated as (

    -- Una fila por objetivo, una por mapa y modo, y una por mapa con todos sus modos
    select
          map_name
        , coalesce(game_mode, 'All modes')                    as game_mode
        , coalesce(objective_location, 'All objectives')      as objective_location
        , count(*)                                            as rounds_played
        , {{ pct_true('is_attacker_win') }}                   as attacker_win_rate_pct
        -- Media de las referencias de sus rondas: en la fila de mapa pondera el peso de cada modo
        , round(avg(mode_attacker_win_rate_pct), 2)           as expected_attacker_win_rate_pct
        , round(avg(iff(is_valid_duration, round_duration_seconds, null)), 0)
                                                              as avg_round_duration_seconds
    from joined
    group by grouping sets (
          (map_name, game_mode, objective_location)
        , (map_name, game_mode)
        , (map_name)
    )

),

with_margin as (

    select
          *
        , round(attacker_win_rate_pct - expected_attacker_win_rate_pct, 2)                  as attacker_win_delta_pp
        , round({{ balance_margin_pp('expected_attacker_win_rate_pct', 'rounds_played') }}, 2) as balance_margin_pp
    from aggregated

),

final as (

    select
          map_name
        , game_mode
        , objective_location
        , rounds_played
        , attacker_win_rate_pct
        , round(100 - attacker_win_rate_pct, 2)               as defender_win_rate_pct
        , expected_attacker_win_rate_pct
        , attacker_win_delta_pp
        , balance_margin_pp
        , avg_round_duration_seconds
        , rounds_played < {{ min_rounds }}                    as is_low_sample
        , case
              when rounds_played < {{ min_rounds }}               then 'Low sample'
              when attacker_win_delta_pp >=  balance_margin_pp    then 'Attacker-sided'
              when attacker_win_delta_pp <= -balance_margin_pp    then 'Defender-sided'
              else 'Balanced'
          end                                                 as balance_status
    from with_margin

)

select * from final
