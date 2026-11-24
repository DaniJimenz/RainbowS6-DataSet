with source as (

    select * from {{ source('ubisoft_r6s', 'player_rounds') }}

),

renamed as (

    -- try_*: un valor mal formado pasa a null y lo detectan los tests not_null del yml
    select
        -- Identificación de la partida y la ronda
          try_to_date(dateid, 'YYYYMMDD')      as match_date
        , matchid                              as match_id
        , try_cast(roundnumber as integer)     as round_number

        -- Contexto de la ronda
        , gamemode                             as game_mode
        , mapname                              as map_name
        , objectivelocation                    as objective_location
        , winrole                              as winning_role
        , endroundreason                       as end_round_reason
        , try_cast(roundduration as integer)   as round_duration_seconds

        -- Jugador
        , skillrank                            as skill_rank
        , role                                 as player_role
        , try_cast(team as integer)            as team_number
        , operator                             as operator_code

        -- Resultado del jugador en la ronda
        , try_cast(haswon as boolean)          as has_won
        , try_cast(nbkills as integer)         as kills
        , try_cast(isdead as boolean)          as is_dead

        -- Metadatos de carga
        , _source_file                         as source_file_name
        , _source_row_number                   as source_row_number
        , _loaded_at                           as loaded_at

    from source

)

select * from renamed