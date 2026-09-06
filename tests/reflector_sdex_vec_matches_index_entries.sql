-- The SDEX reflector model maps prices to assets positionally: an asset's position
-- in the oracle's `assets` vec IS its price-feed index. The contract also still
-- carries its older per-asset address -> u32 index entries; those stopped being
-- maintained at index 48, but wherever one exists it is order-independent ground
-- truth. This test cross-checks every legacy entry against the vec position, so a
-- reordered or truncated vec -- which would silently attribute prices to the wrong
-- (non-null) assets -- fails loudly instead. Known limits: if Reflector deletes the
-- legacy entries the comparison set is empty and this passes trivially, and assets
-- beyond index 48 have no legacy entry to check.

-- Strictly use enabled condition to restrict singular tests from running in dbt build tasks.
-- https://github.com/stellar/stellar-dbt-public/pull/95
{{ config(
    severity=("error" if target.name == "prod" else "warn")
    , tags=["singular_test"]
    , enabled=var("is_singular_airflow_task") == "true"
    , meta={"alert_suppression_interval": 24, "exception_scope": {"entity_columns": ['asset_index'], "allows_day_scope": false}}
    )
}}

with
    legacy_entries as (
        select distinct
            json_extract_scalar(storage_item, '$.key.address') as asset_contract_id
            , cast(json_extract_scalar(storage_item, '$.val.u32') as int) as asset_index
        from {{ ref('contract_data_snapshot') }}
        , unnest(json_extract_array(val_decoded, '$.contract_instance.storage')) as storage_item
        where
            contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
            and contract_durability = 'ContractDataDurabilityPersistent'
            and json_extract_scalar(storage_item, '$.key.address') is not null
            and valid_to is null -- fetch only latest entry
    )

    , vec_positions as (
        select distinct
            json_extract_scalar(asset_entry, '$.vec[1].address') as asset_contract_id
            , asset_index
        from {{ ref('contract_data_snapshot') }}
        , unnest(json_extract_array(val_decoded, '$.contract_instance.storage')) as storage_item
        , unnest(json_extract_array(storage_item, '$.val.vec')) as asset_entry with offset as asset_index
        where
            contract_id = 'CALI2BYU2JE6WVRUFYTS6MSBNEHGJ35P4AVCZYF3B6QOE3QKOB2PLE6M'
            and contract_durability = 'ContractDataDurabilityPersistent'
            and json_extract_scalar(storage_item, '$.key.string') = 'assets'
            and valid_to is null -- fetch only latest entry
    )

select
    legacy_entries.asset_index
    , legacy_entries.asset_contract_id as legacy_contract_id
    , vec_positions.asset_contract_id as vec_contract_id
    , case
        when vec_positions.asset_contract_id is null then 'index_missing_from_vec'
        else 'contract_mismatch_at_index'
    end as failure_reason
from legacy_entries
left join vec_positions
    on legacy_entries.asset_index = vec_positions.asset_index
where
    (
        vec_positions.asset_contract_id is null
        or legacy_entries.asset_contract_id != vec_positions.asset_contract_id
    )
    {{ exclude_test_exceptions(
        ref('public_test_exceptions')
        , entity_columns={'asset_index': 'legacy_entries.asset_index'}
    ) }}
