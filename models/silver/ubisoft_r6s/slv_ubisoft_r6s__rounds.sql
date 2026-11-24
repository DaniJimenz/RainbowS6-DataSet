with player_rounds as (

    select * from {{ ref('slv_ubisoft_r6s__player_rounds') }}

),

rounds as (

    -- Una fila por ronda. Se agrupa por todos los atributos de la ronda: si alguno
    -- variase entre jugadores saldrían varias filas por round_id y el test unique fallaría.
    select
          round_id
        , match_date
        , match_id
        , round_number
        , map_name
        , game_mode
        , objective_location
        , winning_role
        , end_round_reason

        -- La duración varía 1 s aprox entre jugadores
        , max(round_duration_seconds)                       as round_duration_seconds

        -- Recuento de jugadores por bando
        , count(*)                                          as players_count
        , count_if(player_role = 'Attacker')                as attackers_count
        , count_if(player_role = 'Defender')                as defenders_count

    from player_rounds
    group by all

),

final as (

    select
          *
        , round_duration_seconds between {{ var('min_valid_round_duration_seconds') }}
                                     and {{ var('max_valid_round_duration_seconds') }}
                                                            as is_valid_duration
    from rounds

)

select * from final
