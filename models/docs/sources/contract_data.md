[comment]: < Contract Data -

{% docs contract_data %}
The contract data table contains the soroban contract data ledger entries data. Can be joined on contract_id to operations and transactions to get a more detailed view of a whole Soroban contract.
{% enddocs %}

{% docs contract_key_type %}
Contract key type which is an ScVal that can have the following values

| Type                                  |
| ------------------------------------- |
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

{% docs key %}
The encoded key used to identify a specific piece of contract data. The encoded key has two components (type and value) where type describes the data type and the value describes the encoded value of the data type for the contract data.
{% enddocs %}

{% docs key_decoded %}
The human-readable or decoded version of the key. This provides an understandable format of the key, making it easier to interpret and use in analysis.
{% enddocs %}

{% docs val %}
The encoded value associated with the key in the contract data. The encoded val has two components (type and value) where type describes the data type and the value describes the encoded value of the data type for the contract data.
{% enddocs %}

{% docs val_decoded %}
The human-readable or decoded version of the value. This provides a clear and understandable representation of the value, making it easier to interpret and use in analysis.
{% enddocs %}

{% docs contract_data_xdr %}
The XDR (External Data Representation) encoding of the contract data. XDR is a standard format used to serialize and deserialize data, ensuring interoperability across different systems. This field contains the raw, serialized contract data in XDR format.
{% enddocs %}
