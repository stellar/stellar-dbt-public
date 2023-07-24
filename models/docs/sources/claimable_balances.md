[comment]: < Claimable Balances -

{% docs claimable_balances %}

The claimable balances table stores information on when a claimable balance was created and deleted (claimed) on the network. A claimable balance can be seen as an “untrusted” payment, where the sender creates a balance and specifies recipients that can receive the balance. The recipient must authorize the payment to receive, but does not have to wait on the sender to authorize the transaction since it has been preauthorized. Claimable balances have increased in popularity by driving Airdrop and pump and dump scams.

{% enddocs %}

{% docs balance_id %}
A unique identifier for this claimable balance. The Balance id is a compilation of `Balance Type` + `SHA-256 hash history_operation_id`

- Natural Key
- Cluster Field
- Required Field

#### Notes:
The Balance Type is fixed at V0, `00000000`. If there is a protocol change that materially impacts the mechanics of claimable balances, the balance type would update to V1.
{% enddocs %}

{% docs claimants %}
The list of entries which are eligible to claim the balance and preconditions that must be fulfilled to claim.

- Required Field

#### Notes:
Multiple accounts can be specified in the claimants record, including the account of the balance creator.
{% enddocs %}

{% docs claimants_destination %}
The account id who can claim the balance.

- Required Field
{% enddocs %}

{% docs claimants_predicate %}
The condition which must be satisfied so the destination can claim the balance. The predicate can include logical rules using AND, OR and NOT logic.

- Required Field
{% enddocs %}

{% docs claimants_predicate_unconditional %}
If true it means this clause of the condition is always satisfied.

#### Notes:
When the predicate is only unconditional = true, it means that the balance can be claimed under any conditions
{% enddocs %}

{% docs claimants_predicate_abs_before %}
Deadline for when the balance must be claimed. If a balance is claimed before the date then the clause of the condition is satisfied. 
{% enddocs %}

{% docs claimants_predicate_rel_before %}
A relative deadline for when the claimable balance can be claimed. The value represents the number of seconds since the close time of the ledger which created the claimable balance

#### Notes:
This condition is useful when creating a timebounds based on creation conditions. If the creator wanted a balance only claimable one week after creation, this condition would satisfy that rule.
{% enddocs %}

{% docs claimants_predicate_abs_before_epoch %}
A UNIX epoch value in seconds representing the same deadline date as abs_before.
{% enddocs %}


{% docs asset_amount %}
The amount of the asset that can be claimed.

- Required Field
{% enddocs %}
