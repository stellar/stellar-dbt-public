[comment]: < Accounts Signers -

{% docs accounts_signers %}
State tables are divided by the type of data entry stored on the ledger. Account signers is a subset of data related to accounts (it can be viewed as a dimension detail from the accounts table, joining on account_id). Each account on Stellar can specify a list of other accounts, signers, that can authorize transactions for the account. Transactions will only complete successfully if an authorized number of signers has authorized the transaction. More information regarding multisignature transactions can be found [here](https://developers.stellar.org/docs/glossary/multisig/).
{% enddocs %}

{% docs signer_account_id %}
The address of the account in which signers are authorized to sign transactions.

- Natural Key
- Cluster Field
- Required Field
{% enddocs %}

{% docs signer %}
The address of the account that is allowed to authorize (sign) transactions for another account. This process is called multi-sig.

- Natural Key
- Required Field

#### Notes:
For more information on multi-sig, read these [documments](https://developers.stellar.org/docs/encyclopedia/signatures-and-multisig?q=encyclopedia+signatures+and+multisig)
{% enddocs %}

{% docs weight %}
The numeric weight of the signer. All weights on a transaction are added up and used to determine if a transaction meets the threshold requirements to complete the transaction.

- Natural Key

#### Notes:
For example, Account A has a master key weight of 1. If Account A is attempting to submit a payment, but their threshold to complete the transaction is 2, an extra signer with a weight of "1" is required in order to complete the transaction.
{% enddocs %}

{% docs signer_sponsor %}
The account address of the sponsor who is paying the reserves for this signer.
{% enddocs %}

{% docs account_signer_deleted %}
Indicates whether the ledger entry (account id/signer combination) has been deleted or not. Once an entry is deleted, it cannot be recovered.

- Required Field
{% enddocs %}
