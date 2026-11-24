{%- set min_rounds = var('min_rounds_for_map_balance') -%}
{%- set threshold  = var('balance_threshold_pp') -%}

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
    from rounds r
    inner join objectives o on r.objective_key = o.objective_key

),

global_benchmark as (

    -- Referencia: % de victorias del ataque en todas las rondas
    select {{ pct_true('is_attacker_win') }} as global_attacker_win_rate_pct
    from joined

),

aggregated as (

    -- Una fila por objetivo, más una fila por mapa con todos sus modos y objetivos
    select
          map_name
        , coalesce(game_mode, 'All modes')                    as game_mode
        , coalesce(objective_location, 'All objectives')      as objective_location
        , count(*)                                            as rounds_played
        , {{ pct_true('is_attacker_win') }}                   as attacker_win_rate_pct
        , round(avg(iff(is_valid_duration, round_duration_seconds, null)), 0)
                                                              as avg_round_duration_seconds
    from joined
    group by grouping sets (
          (map_name, game_mode, objective_location)
        , (map_name)
    )

),

final as (

    select
          a.map_name
        , a.game_mode
        , a.objective_location
        , a.rounds_played
        , a.attacker_win_rate_pct
        , round(100 - a.attacker_win_rate_pct, 2)             as defender_win_rate_pct
        , g.global_attacker_win_rate_pct
        , round(a.attacker_win_rate_pct - g.global_attacker_win_rate_pct, 2)
                                                              as attacker_win_delta_pp
        , a.avg_round_duration_seconds
        , a.rounds_played < {{ min_rounds }}                  as is_low_sample
        , case
              when a.rounds_played < {{ min_rounds }}                                         then 'Low sample'
              when a.attacker_win_rate_pct - g.global_attacker_win_rate_pct >=  {{ threshold }} then 'Attacker-sided'
              when a.attacker_win_rate_pct - g.global_attacker_win_rate_pct <= -{{ threshold }} then 'Defender-sided'
              else 'Balanced'
          end                                                 as balance_status
    from aggregated a
    cross join global_benchmark g

)

select * from final