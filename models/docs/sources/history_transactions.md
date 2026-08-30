[comment]: < History Transactions >

{% docs history_transactions %}
Trasactions are commands that modify the ledger state and consist of one or more operations. In terms of taxonomy, a ledger contains a transaction set of multiple transactions, and a transaction contains an operation set of one to many operations.
Transactions that are sent to the Stellar Network either succeed completely or fail completely. There is no partial transaction execution. The table is an event log of all transactions submitted and committed to a transaction set within a ledger.
{% enddocs %}

{% docs transaction_id %}
A unique identifier for this transaction.

- Primary Key
- Natural Key
- Cluster Field
- Required Field
  {% enddocs %}

{% docs transaction_hash %}
A hex-encoded SHA-256 hash of this transaction's XDR-encoded form.

- Required Field
  {% enddocs %}

{% docs application_order %}
Each transaction within the transaction set for a ledger is executed and applied sequentially to the network. The validator nodes randomly shuffle submitted transactions and assign them an application order number, which corresponds to the order in which they are applied.

- Required Field
  {% enddocs %}

{% docs account %}
The account address that originates the transaction.

- Cluster Field
- Required Field
  {% enddocs %}

{% docs account_sequence %}
The source account's sequence number that this transaction consumed. Sequence numbers can only be used once and help maintain atomicity and idempotency on the network.

- Required Field
  {% enddocs %}

{% docs max_fee %}
The maximum total fee (in stroops) the inner transaction is willing to pay. For non-fee-bump Soroban transactions, this is the ceiling. For fee-bump transactions, this is superseded by new_max_fee. For Classic transactions, this is the maximum the submitter will pay for inclusion.

- Required Field

#### Notes:

The stroop is the fractional representation of a lumen (XLM). 1 stroop is 0.0000001 XLM.
{% enddocs %}

{% docs transaction_operation_count %}
The number of operations contained within this transaction.

- Required Field

#### Notes:

A transaction is permitted to have up to 100 operations.
{% enddocs %}

{% docs created_at %}
The date the transaction was created.
{% enddocs %}

{% docs memo_type %}
The type of memo.

- Required Field

| Acceptable Values  |
| ------------------ |
| MemoTypeMemoHash   |
| MemoTypeMemoId     |
| MemoTypeMemoNone   |
| MemoTypeMemoReturn |
| MemoTypeMemoText   |

#### Notes:

Defaults to `MemoTypeMemoNone`
{% enddocs %}

{% docs memo %}
An optional freeform field that attaches a memo to a transaction

#### Notes:

Memos are heavily used by centralized exchanges to help with account management.
{% enddocs %}

{% docs time_bounds %}
A transaction precondition that can be set to determine when a transaction is valid. The user can set a lower and upper timebound, defined as a UNIX timestamp when the transaction can be executed.
If the transaction attempts to execute outside of the time range, the transaction will fail
{% enddocs %}

{% docs successful %}
Indicates if this transaction was successful or not

#### Notes:

A transaction's success does not indicate whether it was included and written to a ledger. It only indicates whether the operations in the transaction were successfully applied to mutate the ledger state.
{% enddocs %}

{% docs fee_charged %}
The net total fee (in stroops) actually deducted from the account after all refunds. This is what the submitter ultimately pays. For Classic transactions, fee_charged is the inclusion fee. For Soroban transactions, `fee_charged = inclusion_fee_charged + non_refundable_resource_fee_charged + refundable_resource_fee_charged -  resource_fee_refund`.

#### Notes:

The stroop is the fractional representation of a lumen (XLM). 1 stroop is 0.0000001 XLM.
{% enddocs %}

{% docs inner_transaction_hash %}
A transaction hash of a transaction wrapped with its signatures for fee-bump transactions
{% enddocs %}

{% docs fee_account %}
An account that is not the originating source account for a transaction is allowed to pay transaction fees on behalf of the source account.
These accounts are called fee accounts and incur all transaction costs for the source account.
{% enddocs %}

{% docs new_max_fee %}
The maximum total fee (in stroops) the fee-bump transaction is willing to pay. Only populated on fee-bump transactions. This is the actual ceiling used by the network, superseding max_fee. NULL if not a fee bump.
{% enddocs %}

{% docs account_muxed %}
If the user has defined multiplexed (muxed) accounts, the account exists "virtually" under a traditional Stellar account address.
This address distinguishes between the virtual accounts
{% enddocs %}

{% docs fee_account_muxed %}
If the fee account that sponsors fee is a multiplexed account, the virtual address will be listed here
{% enddocs %}

{% docs ledger_bounds %}
A transaction precondition that can be set to determine valid conditions for a transaction to be submitted to the network.
Ledger bounds allow the user to specify a minimum and maxiumum ledger sequence number in which the transaction can successfully execute
{% enddocs %}

{% docs min_account_sequence %}
A transaction precondition that can be set to determine valid conditions for a transaction to be submitted to the network.
This condition contains an integer representation of the lowest source account sequence number for which the transaction is valid
{% enddocs %}

{% docs min_account_sequence_age %}
A transaction precondition that can be set to determine valid conditions for a transaction to be submitted to the network.
This condition contains a minimum duration of time that must have passed since the source account's sequence number changed for the transaction to be valid
{% enddocs %}

{% docs min_account_sequence_ledger_gap %}
A transaction precondition that can be set to determine valid conditions for a transaction to be submitted to the network.
This condition contains an integer representation of the minimum number of ledgers that must have closed since the source account's sequence number change for the transaction to be valid
{% enddocs %}

{% docs extra_signers %}
An array of up to two additional signers that must have corresponding signatures for this transaction to be valid
{% enddocs %}

{% docs tx_envelope %}
A base-64 encoded XDR blob of the tx envelope (transaction and its signatures)
{% enddocs %}

{% docs tx_result %}
A base-64 encoded XDR blob of the tx result
{% enddocs %}

{% docs tx_meta %}
A base-64 encoded XDR blob of the tx meta
{% enddocs %}

{% docs tx_fee_meta %}
A base-64 encoded XDR blob of the tx fee meta
{% enddocs %}

{% docs resource_fee %}
The portion of the total fee budget allocated to pay for Soroban resource consumption (CPU, reads, writes, rent, events, etc.). This is a pre-execution budget, not what is actually charged -- the actual cost will be <= this amount. Only populated for Soroban transactions (resource_fee > 0).
{% enddocs %}

{% docs soroban_resources_instructions %}
Number of CPU instructions the transaction uses
{% enddocs %}

{% docs soroban_resources_read_bytes %}
Number of bytes read by the transaction
{% enddocs %}

{% docs soroban_resources_write_bytes %}
Number of bytes written by the transaction
{% enddocs %}

{% docs transaction_result_code %}
The detailed result code that outlines why a transaction failed. This code is only useful for failed transactions. The full list of domain values can be found [here](https://pkg.go.dev/github.com/stellar/go/xdr#TransactionResultCode).
{% enddocs %}

{% docs inclusion_fee_bid %}
The maximum the submitter is willing to pay to be included in the ledger (i.e., to compete for ledger space). This is the "tip" to get prioritized during surge pricing. Soroban transactions only.
{% enddocs %}

{% docs inclusion_fee_charged %}
The inclusion fee actually charged. During normal conditions this is 100 stroops for a transaction and 200 for a fee-bump transaction. In surge pricing, this is the lowest amount needed for the transaction to make it into the ledger (as long as it is within the ceiling of the inclusion fee bid). Soroban transactions only.
{% enddocs %}

{% docs resource_fee_refund %}
Represents the unused portion of resource_fee returned to the account after execution. resource_fee is charged from the source account before the transaction is executed, and then refunded resource_fee_refund based on the actual usage.
{% enddocs %}

{% docs tx_signers %}
The public keys of the signers who authorized the transaction. This field lists all the signatories that validated and approved the transaction, ensuring it meets the required authorization thresholds.
{% enddocs %}

{% docs non_refundable_resource_fee_charged %}
The resource fee for non-refundable resources: CPU instructions, read bytes, write bytes, and bandwidth (tx size). Charged based on what was declared in the envelope, regardless of whether the transaction succeeds or fails. From SorobanTransactionMetaExtV1 in tx metadata.
{% enddocs %}

{% docs refundable_resource_fee_charged %}
The resource fee for refundable resources: rent, events, and return value. Charged based on actual usage after execution. Will be 0 for failed transactions since refundable resources are only consumed on success. From SorobanTransactionMetaExtV1 in tx metadata.
{% enddocs %}

{% docs rent_fee_charged %}
The portion of refundable_resource_fee_charged that went to ledger entry TTL extensions (rent). The remainder (refundable_resource_fee_charged - rent_fee_charged) covers events and return value fees. From SorobanTransactionMetaExtV1 in tx metadata.
{% enddocs %}
