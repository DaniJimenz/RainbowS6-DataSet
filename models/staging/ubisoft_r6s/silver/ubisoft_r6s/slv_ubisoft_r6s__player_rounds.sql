with player_rounds as (

    select * from {{ ref('stg_ubisoft_r6s__player_rounds') }}

),

enriched as (

    select
        -- Clave de la ronda (match_id solo no es único)
          {{ dbt_utils.generate_surrogate_key(['match_date', 'match_id', 'round_number']) }} as round_id
        , match_date
        , match_id
        , round_number

        -- Contexto de la ronda
        , game_mode
        , map_name
        , objective_location
        , winning_role
        , end_round_reason
        , round_duration_seconds
        , round_duration_seconds between 20 and 600 as is_valid_duration

        -- Rango del jugador
        , skill_rank
        , case
              when skill_rank in ('Platinum', 'Diamond') then 'Platinum+'
              else skill_rank
          end as skill_rank_group
        , skill_rank <> 'Unranked' as is_ranked

        -- Operador
        , player_role
        , team_number
        , operator_code
        , split_part(operator_code, '-', 1) as operator_unit
        , split_part(operator_code, '-', 2) as operator_name
        , split_part(operator_code, '-', 2) = 'RESERVE' as is_recruit

        -- Resultado del jugador
        , has_won
        , kills
        , is_dead

        -- Metadatos de carga
        , source_file_name
        , source_row_number
        , loaded_at

    from player_rounds

),

deduplicated as (

    -- Un operador normal solo puede aparecer una vez por equipo y ronda
    -- Los reclutas (RESERVE) pueden repetirse todo el rato ( no se duplican )
    select *
    from enriched
    qualify is_recruit
         or row_number() over (
                partition by round_id, team_number, operator_code
                order by source_row_number
            ) = 1

)

select * from deduplicated