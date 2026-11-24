{%- set velvet_shell_operators = var('velvet_shell_operators') -%}

with player_rounds as (

    select * from {{ ref('slv_ubisoft_r6s__player_rounds') }}

),

operators as (

    select distinct
          operator_code
        , player_role
        , operator_unit
        , operator_name
        , is_recruit
    from player_rounds

),

final as (

    select
          {{ dbt_utils.generate_surrogate_key(['operator_code', 'player_role']) }} as operator_key
        , operator_code
        , operator_name
        , operator_unit
        , player_role
        , is_recruit
        , operator_name in ('{{ velvet_shell_operators | join("', '") }}')       as is_velvet_shell_operator
    from operators

)

select * from final