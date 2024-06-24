[comment]: < History Ledgers -

{% docs history_ledgers %}
Each ledger stores the state of the network at a given point in time and contains all changes applied to the network - transactions, operations, etc.
The history_ledgers table summarizes the actions taken within a single ledger and is relevant in determining high level network conditions.
{% enddocs %}

{% docs sequence %}
The sequence number that corresponds to the individual ledgers. As ledgers are written to the network, the sequence is incremented by 1

- Natural Key
- Cluster Field
- Required Field
  {% enddocs %}

{% docs ledger_hash%}
The hex-encoded SHA-256 hash that represents the ledger's XDR-encoded form

- Required Field
  {% enddocs %}

{% docs previous_ledger_hash %}
The hex-encoded SHA-256 hash of the ledger that immediately precedes this ledger
{% enddocs %}

{% docs transaction_count %}
The number of successful transactions submitted and completed by the network in this ledger

- Required Field

#### Notes:

Defaults to 0
{% enddocs %}

{% docs operation_count %}
The total number of successful operations applied to this ledger

- Required Field

#### Notes:

Defaults to 0
{% enddocs %}

{% docs ledger_id %}
Unique identifier for the ledger

- Primary Key
  {% enddocs %}

{% docs total_coins %}
Total number of lumens in circulation

- Required Field
  {% enddocs %}

{% docs fee_pool %}
The sum of all transaction fees

- Required Field
  {% enddocs %}

{% docs base_fee %}
The fee (in stroops) the network charges per operation in a transaction for the given ledger. The minimum base fee is 100, with the ability to increase if transaction demand exceeds ledger capacity. When this occurs, the ledger enters surge pricing.

- Required Field

#### Notes:

The stroop is the fractional representation of a lumen (XLM). 1 stroop is 0.0000001 XLM.
{% enddocs %}

{% docs base_reserve %}
The reserve (in stroops) the network requires an account to retain as a minimum balance in order to be a valid account on the network. The current minimum reserve is 10 XLM.

- Required Field

#### Notes:

The stroop is the fractional representation of a lumen (XLM). 1 stroop is 0.0000001 XLM.
{% enddocs %}

{% docs max_tx_set_size %}
The maximum number of operations that Stellar validator nodes have agreed to process in a given ledger. Since Protocol 11, ledger capacity has been measured in operations rather than transactions.

- Required Field
  {% enddocs %}

{% docs protocol_version %}
The protocol verstion that the Stellar network was running when this ledger was committed. Protocol versions are released ~every 6 months.

- Required Field
  {% enddocs %}

{% docs ledger_header %}
A base64-encoded string of the raw LedgerHeader xdr struct for this ledger
{% enddocs %}

{% docs successful_transaction_count %}
The number of successful transactions submitted and completed by the network in this ledger
{% enddocs %}

{% docs failed_transaction_count %}
The number of failed transactions submitted to the network in this ledger. The transaction was still paid for but contained an error that prevented it from executing
{% enddocs %}

{% docs tx_set_operation_count %}
The total number of operations in the transaction set for this ledger, including failed transactions.
{% enddocs %}
