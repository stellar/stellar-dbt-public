[comment]: < Contract Code -

{% docs contract_code %}
The contract code table contains the soroban ledger entries contract code. This table can be joined on contract_code_hash to operations and transactions to get a more detailed view of a whole Soroban contract.

_Note:_ contract code does not contain the actual wasm. The physical wasm can be accessed through soroban RPC.
{% enddocs %}

{% docs contract_code_ext_v %}
Contract code extention version
{% enddocs %}

{% docs n_data_segment_bytes %}
The total number of bytes used by the data segments in the contract code. Data segments are used to initialize the linear memory of a WebAssembly (WASM) module.
{% enddocs %}

{% docs n_data_segments %}
The number of data segments in the contract code. Data segments define the sections of memory that are initialized with specific values when the WebAssembly module is instantiated.
{% enddocs %}

{% docs n_elem_segments %}
The number of element segments in the contract code. Element segments are used to initialize the tables in a WebAssembly (WASM) module, typically used for functions.
{% enddocs %}

{% docs n_exports %}
The number of exports in the contract code. Exports are functions, memories, tables, or globals that are made available to the host environment by the WebAssembly module.
{% enddocs %}

{% docs n_functions %}
The number of functions defined in the contract code. This includes all the functions that can be executed within the WebAssembly (WASM) module.
{% enddocs %}

{% docs n_globals %}
The number of global variables in the contract code. Globals are variables that hold a single value and can be accessed and modified by the WebAssembly module.
{% enddocs %}

{% docs n_imports %}
The number of imports in the contract code. Imports are functions, memories, tables, or globals that the WebAssembly module requires from the host environment.
{% enddocs %}

{% docs n_instructions %}
The total number of instructions in the contract code. Instructions are the individual operations that the WebAssembly module can execute.
{% enddocs %}

{% docs n_table_entries %}
The number of entries in the tables defined by the contract code. Tables are used to store function references in WebAssembly (WASM) modules.
{% enddocs %}

{% docs n_types %}
The number of types defined in the contract code. Types define the signatures of functions, including the number and type of arguments and return values.
{% enddocs %}
