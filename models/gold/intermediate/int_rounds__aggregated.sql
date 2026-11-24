with player_rounds as (

    select * from {{ ref('slv_ubisoft_r6s__player_rounds') }}

),

aggregated as (

    select
        -- Atributos de la ronda
        -- Si alguno varia saldrían varias filas por round_id y el test unique fallaría.
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

)

select * from aggregated