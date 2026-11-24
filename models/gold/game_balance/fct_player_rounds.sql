with player_rounds as (

    select * from {{ ref('slv_ubisoft_r6s__player_rounds') }}

),

final as (

    select
        -- Clave de la fila (generada en Silver)
          player_round_id

        -- Claves foráneas
        , round_id
        , {{ dbt_utils.generate_surrogate_key(['operator_code', 'player_role']) }} as operator_key
        , {{ dbt_utils.generate_surrogate_key(['skill_rank_group']) }} as skill_rank_key

        -- Contexto
        , match_date
        , team_number

        -- Medidas del jugador en la ronda
        , has_won
        , kills
        , is_dead

    from player_rounds

)

select * from final