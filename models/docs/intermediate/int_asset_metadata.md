{% docs contract_admin %}
The address authorized to perform administrative actions for the contract, such as minting or clawbacks.

#### Notes:
While SEP-41 focuses on a common interface for user operations (transfers, allowances), some contracts also implement an administrative interface compatible with the Stellar Asset Contract (SAC). If an admin is defined, they must authorize specific administrative calls, or the function will trap (halt and revert).

{% enddocs %}

{% docs contract_symbol %}
The short-form ticker or code for the token (e.g., "USDC").

#### Notes:
To comply with the Soroban token interface, this metadata must be written to the ledger in a specific format. This allows downstream systems, such as block explorers and your dbt models, to read the constant data directly from the ledger instead of invoking a Wasm function.

{% enddocs %}

{% docs contract_name %}
The full, human-readable name for the token (e.g., "Circle USD").

#### Notes:
This is part of the standard metadata required for SEP-41 compliance. Consistent naming ensures that the token is handled correctly by explorers and interoperable contracts built to support Soroban's built-in tokens.

{% enddocs %}