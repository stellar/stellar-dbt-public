[comment]: < Contract Data -

{% docs contract_data %}
The contract data table contains the soroban contract data ledger entries data. Can be joined on contract_id to operations and transactions to get a more detailed view of a whole Soroban contract.
{% enddocs %}

{% docs contract_key_type %}
Contract key type which is an ScVal that can have the following values

| Type                                  |
|---------------------------------------|
| ScValTypeScvContractInstance          |
| ScValTypeScvLedgerKeyContractInstance |
| ScValTypeScvLedgerKeyNonce            |
{% enddocs %}

{% docs contract_durability %}
Contract can either be temporary or persistent
{% enddocs %}

{% docs balance_holder %}
The address/account that holds the balance of the asset in contract data
{% enddocs %}
