[comment]: < History Contract Events >

{% docs history_contract_events %}
This table contains all contract events, diagnostic events, and system events. Events cover a wide variety of information including token value movement, core metrics, and logging/debugging information.

After CAP-67 is implemented this table will also contain events for classic operations.
{% enddocs %}

{% docs in_successful_contract_call %}
Indicates whether or not the event is in a successful contract call
{% enddocs %}

{% docs event_type %}
The numeric event type

| type | type string                 |
| ---- | --------------------------- |
| 0    | ContractEventTypeSystem     |
| 2    | ContractEventTypeDiagnostic |
| 1    | ContractEventTypeContract   |
{% enddocs %}

{% docs event_type_string %}
The string event type

| type | type string                 |
| ---- | --------------------------- |
| 0    | ContractEventTypeSystem     |
| 2    | ContractEventTypeDiagnostic |
| 1    | ContractEventTypeContract   |
{% enddocs %}

{% docs event_topics %}
The topics part of an event contains identifying information and metadata for the event and generally what the event signifies. For example, for SAC this could be a "transfer" event signifying token value movement.

The values within topics are base64 encoded XDR
{% enddocs %}

{% docs event_topics_decoded %}
Decoded, human readable version of the event topic
{% enddocs %}

{% docs event_data %}
The data part of an event is an object that contains the value(s) significant to an event. For example, for SAC this could be the "amount" of the token movement from a "transfer" event.

The values within topics are base64 encoded XDR
{% enddocs %}

{% docs event_data_decoded %}
Decoded, human readable version of the event data object
{% enddocs %}

{% docs contract_event_xdr %}
The base64 encoded XDR of the event
{% enddocs %}
