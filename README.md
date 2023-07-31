# stellar-dbt-public
Public DBT instance to aid in data transformation for analytics purposes

## Table of Contents


## Getting Started 

In order to develop on this repository, we must first get dbt and follow the installation procedure. First of all, clone the git repository locally. Afterwards, you can follow best practices by setting up a virtual environment for dbt installation or installing it directly (In that case, you can skip to the [dbt setup](#setting-up-dbt)).

After cloning, create a virtual environment for the installation. The recommended python version for dbt is 3.8 and any of its patches.

1. Follow the guide and install the [virtualenv package](https://virtualenv.pypa.io/en/latest/installation.html) through any of the available methods.

2. In order to create a virtual environment, run the command: ``` virtualenv {{env_name}} -p {{python-version}} ```, in case you wish for an specific python environment version, or simply run ``` virtualenv {{env_name}} ``` to install the system's python version on the current repository. More information can be obtained [here](https://virtualenv.pypa.io/en/latest/user_guide.html).

3. Source the virtual environment through: ``` source ~/path/to/venv/bin/activate ```

## dbt Setup

1. Run ``` pip install -r requirements.txt ``` to install all the necessary packages.

2. Run ``` dbt deps ``` to install the utils packages from dbt.

3. Following best practices, each developer has his own dataset for dbt transformations, but shares the same sources. Open the  `profiles.yml` file on your project folder and add the following configurations:
``` YML
name: 'stellar_dbt'
version: '1.0.0'
config-version: 2

profile: 'stellar_dbt'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

models:
  stellar_dbt:
    samples:
      +enabled: "{{ target.name=='samples' }}"
      +docs:
        show: false
      +materialized: table
    staging:
      +materialized: view
      +dataset: raw
    intermediate:
      +materialized: table
      +dataset: conformed
    marts:
      +materialized: table
      +dataset: marts
      ledger_current_state:
        +materialized: table
        +tags: current_state
  
  elementary:
    +schema: elementary
    +docs:
      show: false
    +materialized: table
```
## Working with dbt

### Running Models

Executing a dbt model is the same as executing a SQL script. There are many ways to run dbt models: 

1. Run the entire project through `dbt run`

2. Run tagged models, paths or configs through `dbt run --select tag:tag_1 tag_2 tag_3`.

3. Run specific models through `dbt run --select model_1 model_2 model_3`. **Note that this runs only the specified models, unless you follow said model(s) with execution method #4**

4. Run downstream or upstream models by adding a '+' at the beginning(downstream), end(upstream) or both on the model name `dbt run --select +model_1+`

On top of that, dbt supports --excluding, --defer, --target and many other selection types. To see more, please refer to the [documentation](https://docs.getdbt.com/reference/node-selection/syntax).

### Running Tests

Executing tests works the same way as executing runs, with the command `dbt test` accepting many of the same parameters. This will run both schema tests and unique tests, unless commanded otherwise. For more information on the syntax, consult the [documentation](https://docs.getdbt.com/reference/node-selection/syntax).

In dbt, tests come in two ways. Schema tests, which are pre-built macros and can be called in YML schema files, and unique tests, which are user-made and have their own .SQL files, stored in the `tests` folder. Both tests will be executed during a `dbt test`, unless further node selection is provided. A dbt test will fail when the underlying SQL selection returns a result row, being approved when no rows are returned. For further information on tests, please refer to the [documentation](https://docs.getdbt.com/reference/test-configs).


## Working with samples

In order to reduce costs, sample tables were created from the `crypto_stellar.crypto_stellar` dataset, so fewer bytes would be processed while developing. These sources are already created and properly sourced. The Queries used for the creation of the samples can be found inside the `samples` folder.

If there is a need, the samples can be refreshed by selecting a sample period through the `where batch_run_date between {batch_run_start} and {batch_run_finish}` clause in each respective table script, and running dbt with the command `dbt run --target samples`.**It is important to select the same period for every sample table, in order to enable the necessary joins.**

## Project Structure

The Stellar-dbt project follows a staging/marts approach to modelling. The staging step focuses on transforming and preparing the tables for joining on the marts step. In order to diminish cost, all staging .sql files are materialized as ephemeral in the `dbt_project.yml`, allowing code modularity and decoupling while not raising storage costs. 

The marts, on the other hand, are materialized as tables, in order to reduce querying time on the BI and other exposures. It is in this step that tables are joined together to obtain analytical results or rejoin needed information to facilitate date exploration.

### Development Folders

| Name | Description |
|------|-------------|
|Sources| Contains the config files for the product source tables, referencing their documentation and, when necessary, testing the raw data with schema tests |
|Samples| Contains the scripts to recreate the sample tables used as sources during development |
|Staging| Scripts that prepare and transform the raw tables for joining and analyses |
|Marts| Scripts that create the Enriched tables as well as analytical tables for partner and BI consumption |
|Docs| Contains the documentation files for the project, used to generate the hosted documentation |
|Macros| Contains any custom Jinja macros created for the project |
|Tests| Contains any custom tests created for the project |



