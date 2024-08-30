{{ config(
    tags = ["enriched_history_operations"]
    )
}}

with
    raw_table as (
        select *
        from {{ source('crypto_stellar', 'history_effects') }}
    )

    , history_effects as (
        select
            id
            , ledger_sequence
            , address
            , address_muxed
            , operation_id
            , type
            , type_string
            , details.liquidity_pool
            , details.reserves_received
            , details.reserves_deposited
            , details.reserves_revoked
            , details.bought
            , details.sold
            , details.shares_revoked
            , details.shares_received
            , details.shares_redeemed
            , details.liquidity_pool_id
            , details.balance_id
            , details.new_seq
            , details.name
            , details.value
            , details.trustor
            , details.limit
            , details.inflation_destination
            , details.authorized_flag
            , details.auth_immutable_flag
            , details.authorized_to_maintain_liabilites
            , details.auth_revocable_flag
            , details.auth_required_flag
            , details.auth_clawback_enabled_flag
            , details.claimable_balance_clawback_enabled_flag
            , details.clawback_enabled_flag
            , details.high_threshold
            , details.med_threshold
            , details.low_threshold
            , details.home_domain
            , details.asset_issuer
            , details.asset
            , details.asset_code
            , details.signer
            , details.sponsor
            , details.new_sponsor
            , details.former_sponsor
            , details.weight
            , details.public_key
            , details.asset_type
            , details.amount
            , details.starting_balance
            , details.seller
            , details.seller_muxed
            , details.seller_muxed_id
            , details.offer_id
            , details.sold_amount
            , details.sold_asset_type
            , details.sold_asset_code
            , details.sold_asset_issuer
            , details.bought_amount
            , details.bought_asset_type
            , details.bought_asset_code
            , details.predicate
            , details.data_name
            , details.bought_asset_issuer
            , details.contract_event_type
            , details.contract
            , details.ledgers_to_expire
            , details.entries
            , details.extend_to
            , index
            , closed_at
            , batch_id
            , batch_run_date
        from raw_table
    )

select *
from history_effects
