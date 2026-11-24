{%- set min_rounds = var('min_player_rounds_for_balance') -%}
{%- set threshold  = var('balance_threshold_pp') -%}

with player_rounds as (

    select * from {{ ref('fct_player_rounds') }}

),

operators as (

    select * from {{ ref('dim_operators') }}

),

skill_ranks as (

    select * from {{ ref('dim_skill_ranks') }}

),

joined as (

    -- Casos de uso 1 y 3: solo operadores reales y jugadores con rango
    select
          o.operator_name
        , o.operator_unit
        , o.player_role
        , o.is_velvet_shell_operator
        , s.skill_rank_group
        , s.rank_order
        , f.has_won
        , f.kills
        , f.is_dead
    from player_rounds f
    inner join operators o   on f.operator_key   = o.operator_key
    inner join skill_ranks s on f.skill_rank_key = s.skill_rank_key
    where not o.is_recruit
      and s.is_ranked

),

aggregated as (

    -- Una fila por operador y rango, más una fila 'All ranks' por operador
    select
          operator_name
        , operator_unit
        , player_role
        , is_velvet_shell_operator
        , coalesce(skill_rank_group, 'All ranks')       as skill_rank_group
        , coalesce(rank_order, 99)                      as rank_order
        , count(*)                                      as player_rounds
        , count_if(has_won)                             as wins
        , sum(kills)                                    as total_kills
        , count_if(is_dead)                             as deaths
        , {{ pct_true('has_won') }}                     as win_rate_pct
        , {{ pct_true('not is_dead') }}                 as survival_rate_pct
        , round(avg(kills), 2)                          as avg_kills
    from joined
    group by grouping sets (
          (operator_name, operator_unit, player_role, is_velvet_shell_operator, skill_rank_group, rank_order)
        , (operator_name, operator_unit, player_role, is_velvet_shell_operator)
    )

),

benchmarked as (

    -- Comparación contra la media del bando en el mismo rango
    select
          *
        , round(100 * sum(wins) over (partition by player_role, skill_rank_group)
                    / sum(player_rounds) over (partition by player_role, skill_rank_group), 2)
                                                        as role_win_rate_pct
        , round(100 * player_rounds
                    / sum(player_rounds) over (partition by player_role, skill_rank_group), 2)
                                                        as pick_share_pct
        , round(total_kills / nullif(deaths, 0), 2)     as kd_ratio
    from aggregated

),

final as (

    select
          operator_name
        , operator_unit
        , player_role
        , is_velvet_shell_operator
        , skill_rank_group
        , rank_order
        , player_rounds
        , pick_share_pct
        , win_rate_pct
        , role_win_rate_pct
        , round(win_rate_pct - role_win_rate_pct, 2) as win_rate_delta_pp
        , survival_rate_pct
        , avg_kills
        , kd_ratio
        , player_rounds < {{ min_rounds }} as is_low_sample
        , case
              when player_rounds < {{ min_rounds }}                        then 'Low sample'
              when win_rate_pct - role_win_rate_pct >=  {{ threshold }}    then 'Overperforming'
              when win_rate_pct - role_win_rate_pct <= -{{ threshold }}    then 'Underperforming'
              else 'Balanced'
          end                                           as balance_status
    from benchmarked

)

select * from final