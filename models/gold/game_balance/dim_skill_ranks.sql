with skill_rank_groups as (
select * from {{ ref('skill_rank_groups') }}
),

final as (

    select
          {{ dbt_utils.generate_surrogate_key(['skill_rank_group']) }} as skill_rank_key
        , skill_rank_group
        , rank_order
        , is_ranked
    from skill_rank_groups

)

select * from final