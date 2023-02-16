/* This query selects the deduplicated assets from the new load */
with new_load as (
  select *
  from {{ ref('stg_history_assets') }}
)

/* selects the deduplicated table for comparision */
, deduplicated_table as (
 select *
 from {{this}}
)

/* excludes any assets from the load that already exist in the deduplicated table */
, exclude_duplicates as (
  select
    new_load_dedup.asset_code
    , new_load_dedup.asset_issuer
    , new_load_dedup.asset_type
  from new_load_dedup
  left join deduplicated_table on
    new_load_dedup.asset_code = deduplicated_table.asset_code
    and new_load_dedup.asset_issuer = deduplicated_table.asset_issuer
    and new_load_dedup.asset_type = deduplicated_table.asset_type
  where deduplicated_table.asset_code is null
    and deduplicated_table.asset_issuer is null
    and deduplicated_table.asset_type is null
)

/* Adds only the new assets from the load to the assets table */
, add_assets as (
    select
        new_load_dedup.id
        , exclude_duplicates.asset_type
        , exclude_duplicates.asset_code
        , exclude_duplicates.asset_issuer
        , new_load_dedup.batch_id
        , new_load_dedup.batch_run_date
        , new_load_dedup.batch_insert_ts
    from exclude_duplicates
    left join new_load_dedup on
        exclude_duplicates.asset_type = new_load_dedup.asset_type
        and exclude_duplicates.asset_code = new_load_dedup.asset_code
        and exclude_duplicates.asset_issuer = new_load_dedup.asset_issuer
    union all
    select *
    from deduplicated_table
)

select *
from add_assets