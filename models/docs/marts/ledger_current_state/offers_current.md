[comment]: < Offers Current -

{% docs offers_current %}

The `offers_current` table is a nightly snapshotted table that represents the current orderbook of the Stellar Decentralized Exchange. The table returns the latest offer, which is defined as the highest `last_modified_ledger` per offer on the Stellar Network. Deleted offers are included in the table. An offer is deleted when the seller either updates their offer price to zero or an order is completely filled. For full orderbook history, please use the `offers` table.

**The `offers_current` table is only updated nightly. Intraday ledger state changes are not captured in the table.**

For more information on how the Stellar Decentralized Exchange works, please read [these docs](https://developers.stellar.org/docs/encyclopedia/liquidity-on-stellar-sdex-liquidity-pools#order-books).

{% enddocs %}
