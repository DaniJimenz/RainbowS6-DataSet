with rounds as (

    select * from {{ ref('slv_ubisoft_r6s__rounds') }}

),

objectives as (

    select distinct
          map_name
        , game_mode
        , objective_location
    from rounds

),

final as (

    select
          {{ dbt_utils.generate_surrogate_key(['map_name', 'game_mode', 'objective_location']) }}
                                                        as objective_key
        , map_name
        , game_mode
        , objective_location
    from objectives

)

select * from final