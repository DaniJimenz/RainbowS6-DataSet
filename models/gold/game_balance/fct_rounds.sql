with rounds as (

    select * from {{ ref('slv_ubisoft_r6s__rounds') }}

),

final as (

    select
        -- Clave de la ronda y clave foránea a la dimensión de objetivos
          round_id
        , {{ dbt_utils.generate_surrogate_key(['map_name', 'game_mode', 'objective_location']) }} as objective_key

        -- Contexto
        , match_date
        , match_id
        , round_number

        -- Resultado de la ronda
        , winning_role
        , winning_role = 'Attacker'                         as is_attacker_win
        , end_round_reason

        -- Duración
        , round_duration_seconds
        , is_valid_duration

        -- Jugadores
        , players_count
        , attackers_count
        , defenders_count

    from rounds

)

select * from final