with source as (

    select * from {{ source('ubisoft_r6s', 'player_rounds') }}

),

renamed as (

    select
        -- Identificación de la partida y la ronda
          to_date(dateid, 'YYYYMMDD')          as match_date
        , matchid                              as match_id
        , cast(roundnumber as integer)         as round_number

        -- Contexto de la ronda
        , gamemode                             as game_mode
        , mapname                              as map_name
        , objectivelocation                    as objective_location
        , winrole                              as winning_role
        , endroundreason                       as end_round_reason
        , cast(roundduration as integer)       as round_duration_seconds

        -- Jugador
        , skillrank                            as skill_rank
        , role                                 as player_role
        , cast(team as integer)                as team_number
        , operator                             as operator_code

        -- Resultado del jugador en la ronda
        , cast(haswon as boolean)              as has_won
        , cast(nbkills as integer)             as kills
        , cast(isdead as boolean)              as is_dead

        -- Metadatos de carga
        , _source_file                         as source_file_name
        , _source_row_number                   as source_row_number
        , _loaded_at                           as loaded_at

    from source

)

select * from renamed