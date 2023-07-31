# stellar-dbt-public
Public DBT instance to aid in data transformation for analytics purposes

## Table of Contents
- [Data Transformation](#data-transformation)
    - [Workflow](#workflow)
    - [dbt project structure](#dbt-project-structure)
    - [testing](#testing)
- [Getting Started](#getting-started)
    - [Oauth connection](#oauth)
- [dbt Setup](#dbt-setup)    
- [Working with dbt](#working-with-dbt)
    - [Running Models](#running-models)
    - [Running Tests](#running-tests)
- [Project Structure](#project-structure)
    - [Development Folders](#development-folders)


## Data Transformation 

dbt is composed of different moving parts working harmoniously. All of them are important to what dbt does — transforming data.  When you execute dbt run, you are running a model that will transform your data without that data ever leaving your warehouse.

### Workflow

The top level of a dbt workflow is the project. A project is a directory of a `.yml` file (the project configuration) and either `.sql` or `.py` files (the models). The project file tells dbt the project context, and the models let dbt know how to build a specific data set.

A model is a single file containing a final select statement, and a project can have multiple models, and models can even reference each other.

In dbt, you can configure the materialization of your models. Materializations are strategies for persisting dbt models in a warehouse. There are four types of materializations built into dbt. They are:
1. table (your model is rebuilt as a table on each run)
2. view (your model is rebuilt as a view on each run)
3. incremental (allow dbt to insert or update records into a table since the last time that dbt was run.)
4. ephemeral (models are not directly built into the database. instead, dbt will interpolate the code from this model into dependent models as a common table expression.)

### dbt project structure

1. Staging (data preparation)
The purpose of the source layer is to receive the raw data from the source and define preparations for further analysis.

What to do on staging:

-column selection
-consistently renaming columns.
-definition of data types (casting columns to String, Numeric...)
-flattening of structured objects
-initial filters
-tests (source.yml)
-basic cleanup, like replacing empty strings with NULL, for example

What is not done in the source:

-joins
-creating business rules

2. Intermediate (data preparation)
In the intermediate layer, the preparation for directing the data to the marts takes place. Not every table in the staging layer will become an intermediate. In staging, it is possible to combine different tables to start assembling business rules.

What is done in the intermediate:

-join between different source queries
-more complex functions that would not enter the staging layer
-aggregations
-creation of business metrics/rules

What not to do in intermediate:

-opening of sources
-dimensional modeling (separation of facts, dimensions and marts)

3. Marts (final transformations)
In the marts layer, data is organized for the dimensional model, as well as the configuration for incremental materialization of final tables. Each model will be accompanied by a `.yml` file with the same name. This file contains model and column descriptions and tests.

What is done at the marts:

-organization of data in a dimensional model (star schema)
-creation of sk keys
-mart-specific tweaks
-join between sources and/or stagings
-documentation and testing

What not to do at marts:

-data cleaning
-opening of staging

The models are divided into:

-Dimension tables (dim_table): where the dimensions of the models will be defined and gather all the sources of the respective dimension;
-Fact tables (fct_table): where the final models of the business strategy to be analyzed will be located;
-Aggregate tables (agg_table): where are aggregations of fact tables by one dimension.

### testing

Tests are assertions you make about your models and other resources in your dbt project (e.g. sources, seeds and snapshots). When you run dbt test, dbt will tell you if each test in your project passes or fails. Like almost everything in dbt, tests are SQL queries. In particular, they are select statements that seek to grab "failing" records, ones that disprove your assertion. 

There are two ways of defining tests in dbt:

1. A singular test is testing in its simplest form: If you can write a SQL query that returns failing rows, you can save that query in a `.sql` file within your test directory.
2. A generic test is a parameterized query that accepts arguments. The test query is defined in a special test block (like a macro). Once defined, you can reference the generic test by name throughout your `.yml` files—define it on models, columns, sources, snapshots, and seeds.


## Getting Started 

In order to develop on this repository, we must first get dbt and follow the installation procedure. First of all, clone the git repository locally. Afterwards, you can follow best practices by setting up a virtual environment for dbt installation or installing it directly (In that case, you can skip to the [dbt setup](#setting-up-dbt)).

After cloning, create a virtual environment for the installation. The recommended python version for dbt is 3.8 and any of its patches.

1. Follow the guide and install the [virtualenv package](https://virtualenv.pypa.io/en/latest/installation.html) through any of the available methods.

2. In order to create a virtual environment, run the command: ``` virtualenv {{env_name}} -p {{python-version}} ```, in case you wish for an specific python environment version, or simply run ``` virtualenv {{env_name}} ``` to install the system's python version on the current repository. More information can be obtained [here](https://virtualenv.pypa.io/en/latest/user_guide.html).

3. Source the virtual environment through: ``` source ~/path/to/venv/bin/activate ``` on Linux and ```.\venv\Scripts\activate.ps1``` on Windows. (It must be activated each time you open the project). Ensure that you are in the folder where the virtual environment was created. If it is activated correctly, the terminal will display a flag (venv). To deactivate the virtual environment, simply run the command: ```deactivate```

3. By invoking dbt from the CLI, it should parse `dbt_project.yml` and, in case it doesn't already exist, create a `~/.dbt/profiles.yml`. This file exists outside of the project to avoid sensitive credentials in the version control code and it's not recommended to change it's location. **There exists a profile.yml file inside the project folder, but it is not used when developing locally, only for the CI/CD pipeline, and it must not contain any exposed access keys**.

4. In order to connect to the bigquery project, there are a couple methods of authentication supported by BQ. The BigQuery account to be used must be your personal account. We recommend using Oauth to connect through gcloud CLI tools. Any extra information can be found on the official dbt-bigquery adapter [documentation](https://docs.getdbt.com/reference/warehouse-setups/bigquery-setup#).

### Oauth
5. Oauth - Follow the GCP CLI installation guide [here](https://cloud.google.com/sdk/docs/install). After the installation, run `gcloud init` and provide the requested account information in order to properly setup your Oauth GCP account. The account will be used to run the queries and access the database, so you should use your GCP personal account for that.

6. Open the `profiles.yml` file and add the following configurations:
``` YML
{{my_dbt_project_name}}:
  outputs:
    development:
      dataset: your_dbt_dataset ##the name of your dataset.
      maximum_bytes_billed: 5500000000 #this field limits the maximum number of processed bytes. it helps control processing costs, we recommend 5500000000.
      job_execution_timeout_seconds: 300 ##the number of seconds dbt should wait for queries to complete, after being submitted successfully. we sugest 300 seconds. 
      job_retries: 1 ##the number of times that dbt will retry failing queries. the default is 1.
      location: your-location ##your BQ dataset location
      method: oauth
      priority: interactive ##the priority for the BQ jobs that dbt executes.
      project: your_bigquery_project_name ##your GCP project id
      threads: 1 ##the number of threads represents the maximum number of paths through the graph dbt may work on at once. we recommed 1
      type: bigquery
  target: development
```
In order to avoid any additional costs, the same location of your BigQuery dataset should be used.

For more information on `profiles.yml` setup, please refer to the dbt [documentation](https://docs.getdbt.com/reference/project-configs/profile).

## dbt Setup

1. Run ``` pip install -r requirements.txt ``` to install all the necessary packages.

2. To verify if all libraries have been correctly installed, use the command ```pip list```.

3. Run ``` dbt deps ``` to install the utils packages from dbt.

3. Following best practices, a dbt project informs dbt about the contect of your project and how to transform your data. To do so, open the ```dbt_project.yml``` project configuration file on your dbt project folder.
``` YML
name: 'your_dbt_project_name' ##the name of a dbt project.
version: '1.0.0' ##version of your project.
config-version: 2 ##specify your dbt_project.yml as using the v2 structure.

profile: 'your_profile' ##the profile dbt uses to connect to your data platform.

model-paths: ["models"] ##specify a custom list of directories where models and sources are located.
analysis-paths: ["analyses"] ##specify a custom list of directories where analyses are located.
test-paths: ["tests"] ##directories to where your singular test files live.
seed-paths: ["seeds"] ##specify a custom list of directories where seed files are located.
macro-paths: ["macros"] ##specify a custom list of directories where macros are located.
snapshot-paths: ["snapshots"] ##directories to where your snapshots live.

target-path: "target" ##specify a custom directory where compiled files (e.g. compiled models and tests) will be written when you run the dbt run, dbt compile, or dbt test command.
clean-targets: ##specify a custom list of directories to be removed by the dbt clean command.
  - "target"
  - "dbt_packages"

models:
  {{my_dbt_project_name}}:
    staging:
      +materialized: view ##how your stagings models will materialized.
      +dataset: raw ##the subfolder that will be created within your dataset models where the stagings will be located.
    intermediate:
      +materialized: table ##how your intermediate models will materialized.
      +dataset: conformed ##the subfolder that will be created within your dataset models where the intermediates will be located.
    marts:
      +materialized: table ##how your marts models will materialized.
      +dataset: marts ##the subfolder that will be created within your dataset models where the marts will be located.
      ledger_current_state:
        +materialized: table  ##how your ledger current state model will materialized.
        +tags: current_state ##tag used to resource selection syntax.
```

4. You can also execute the command `dbt debug` to ensure that all configurations are working correctly, and it is possible to initiate data loading and transformation.

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

## Project Structure

The Stellar-dbt project follows a staging/marts approach to modelling. The staging step focuses on transforming and preparing the tables for joining on the marts step. In order to diminish cost, all staging .sql files are materialized as ephemeral in the `dbt_project.yml`, allowing code modularity and decoupling while not raising storage costs. 

The marts, on the other hand, are materialized as tables, in order to reduce querying time on the BI and other exposures. It is in this step that tables are joined together to obtain analytical results or rejoin needed information to facilitate date exploration.

### Development Folders

| Name | Description |
|------|-------------|
|Source| Contains the config files for the product source tables, referencing their documentation and, when necessary, testing the raw data with schema tests |
|Staging| Scripts that prepare and transform the raw tables for joining and analyses |
|Intermediate| Scripts that preparer the data to the marts layer, it is possible to combine different tables to start assembling the business rules. 
|Marts| Scripts that create the Enriched tables as well as analytical tables for partner and BI consumption |
|Docs| Contains the documentation files for the project, used to generate the hosted documentation |
|Macros| Contains any custom Jinja macros created for the project |
|Tests| Contains any custom tests created for the project |



