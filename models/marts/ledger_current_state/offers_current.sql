{% set meta_config = {
    "materialized": "incremental",
    "unique_key": "offer_id",
    "cluster_by": ["selling_asset_code", "selling_asset_issuer", "buying_asset_code", "buying_asset_issuer"],
    "tags": ["current_state"]
} %}

{{ config(
    meta=meta_config,
    **meta_config,
    )
}}

with
    current_offers as (
        select
            o.seller_id
            , o.offer_id
            , o.selling_asset_type
            , o.selling_asset_code
            , o.selling_asset_issuer
            , o.buying_asset_type
            , o.buying_asset_code
            , o.buying_asset_issuer
            , o.amount
            , o.pricen
            , o.priced
            , o.price
            , o.flags
            , o.last_modified_ledger
            , o.closed_at
            , o.ledger_entry_change
            , o.deleted
            , o.sponsor
            , o.batch_run_date
            , row_number()
                over (
                    partition by o.offer_id
                    order by o.last_modified_ledger desc, o.ledger_entry_change desc
                ) as row_nr
        from {{ ref('stg_offers') }} as o

        {% if is_incremental() %}
            -- limit the number of partitions fetched
            where
                timestamp(o.batch_run_date) >= timestamp_sub('{{ dbt_airflow_macros.ts(timezone=none) }}', interval 7 day)
        {% endif %}

    )
select
    seller_id
    , offer_id
    , selling_asset_type
    , selling_asset_code
    , selling_asset_issuer
    , buying_asset_type
    , buying_asset_code
    , buying_asset_issuer
    , amount
    , pricen
    , priced
    , price
    , flags
    , last_modified_ledger
    , closed_at
    , ledger_entry_change
    , deleted
    , sponsor
    , batch_run_date
    , '{{ var("airflow_start_timestamp") }}' as airflow_start_ts
from current_offers
where row_nr = 1
