# Running Macro

The following guide will walk you through the process of running your first Macro model.

## Running Macro Example Cases

Once Macro is installed, the simplest way to get started is to run one of the pre-defined example cases. These examples are hosted in the [MacroEnergyExamples.jl](https://github.com/macroenergy/MacroEnergyExamples.jl) repository and can be downloaded directly using Macro's built-in functions. The steps to run an example case are as follows:
1. Make sure you have correctly installed the Macro package (see [Installation](@ref) for more details).
2. Run the Macro `list_examples()` function to list all available example cases.
3. Download the example case by running `download_example("example_case_name", "ExampleSystems")`, where `example_case_name` is the name of the example case you want to download and `ExampleSystems` is the directory where you want to download the example case.
4. Run the example case by executing the `run.jl` file present in the example folder.
5. Once the model has run, you can analyze the results by looking at the files written in the `results` directory.

The following section will walk you through the process of running the "multisector\_3zone\_simpleinputs" example case. However, you can run any of the example cases available in the [MacroEnergyExamples.jl](https://github.com/macroenergy/MacroEnergyExamples.jl) repository by following the same steps.

!!! tip "Downloading the Full Example Systems Repository"
    Users can always download all the example systems by directly cloning the [MacroEnergyExamples.jl](https://github.com/macroenergy/MacroEnergyExamples.jl) GitHub repository:
    ```bash
    git clone https://github.com/macroenergy/MacroEnergyExamples.jl.git
    ```
    This will download the full MacroEnergyExamples.jl repository into the current working directory.

### Downloading the "multisector\_3zone\_simpleinputs" example case

This example case is a simple multisector 3-zone system modelled loosely on the Eastern USA, with the following sectors:

- Electricity
- Natural Gas
- CO2
- Hydrogen
- Biomass
- Uranium
- Carbon Capture
- Liquid Fuels

Once you have installed the Macro package, open a terminal and run the following command to list all available example cases:

**If Macro was installed following the [Installation Steps](@ref):**
```bash
julia -e 'using MacroEnergy; list_examples()'
```

**If Macro was installed following the [Source Code Installation Steps](@ref):**
```bash
julia --project=/path/to/MacroEnergy.jl -e 'using MacroEnergy; list_examples()'
```
where `/path/to/MacroEnergy.jl` is the path to your cloned Macro repository.

This will print the names of all available example cases.

To download the "multisector\_3zone\_simpleinputs" example case into the `ExampleSystems` directory, run the following command:

**If Macro was installed following the [Installation Steps](@ref):**
```bash
julia -e 'using MacroEnergy; download_example("multisector_3zone_simpleinputs", "ExampleSystems")'
```

**If Macro was installed following the [Source Code Installation Steps](@ref):**
```bash
julia --project=/path/to/MacroEnergy.jl -e 'using MacroEnergy; download_example("multisector_3zone_simpleinputs", "ExampleSystems")'
```
where `/path/to/MacroEnergy.jl` is the path to your cloned Macro repository.

### Running the "multisector\_3zone\_simpleinputs" example case

To run the "multisector\_3zone\_simpleinputs" example case, execute the `run.jl` file present in the example case directory (for Windows machines, see the Note box below):

**If Macro was installed following the [Installation Steps](@ref):**
```bash
julia ExampleSystems/multisector_3zone_simpleinputs/run.jl
```

**If Macro was installed following the [Source Code Installation Steps](@ref):**
```bash
julia --project=/path/to/MacroEnergy.jl ExampleSystems/multisector_3zone_simpleinputs/run.jl
```
where `/path/to/MacroEnergy.jl` is the path to your cloned Macro repository.

!!! note "Windows users"
    On Windows, use backslashes for paths:
    ```bash
    julia ExampleSystems\multisector_3zone_simpleinputs\run.jl
    ```
    or for source code installation:
    ```bash
    julia --project=\path\to\MacroEnergy.jl ExampleSystems\multisector_3zone_simpleinputs\run.jl
    ```

This will use Macro to solve the example system and save the results in the `results` directory. By default, Macro writes the following files:

- `capacity.csv`: capacity results for each asset (final, newly installed, and retired capacity for each technology).
- `costs.csv`: fixed, variable, and total system costs (for multiple periods, present value at the beginning of the modeling horizon).
- `undiscounted_costs.csv`: fixed, variable, and total system costs (for multiple periods, present value at the point in time when the costs were incurred).
- `flow.csv`: flow results for each commodity through each edge.
- `balance_duals.csv`: demand balance constraint duals (marginal prices) for each node.
- `co2_cap_duals.csv`: CO2 cap constraint duals (carbon prices) for each node (only if CO2 cap constraints are enabled).

Congratulations, you just ran your first Macro model! 🎉

## Running a user-defined case with Macro

To run Macro with a user-defined case, you need to create a folder `MyCase` with a minimum of the following structure (customized cases can have additional files and folders (refer to the example cases, for specific details)):

```ASCII
MyCase
├── assets/
├── settings/
├── system/
├── run.jl
├── run_HiGHS.jl
├── run_with_env.jl
└── system_data.json
```

where the `assets` folder consists of the details of the configurations of the different resources modeled as assets within Macro (e.g. the location of the nodes, edges, types of resources, such as BECCS, electrolyzers, hydrostorage units etc.). The `settings` folder contains the configuration files for the constraint scaling and writing subcommodities, the `system` folder contains the `.csv` and `.json` input files related to timeseries data and the system under study.

For instance, one case could have the following structure:

```ASCII
MyCase
│ 
├── settings
│   └── macro_settings.yml           # Macro settings
│ 
├── system
│   ├── Period_map.csv
│   ├──availability.csv
│   ├──commodities.json
│   ├──demand fuel.csv
│   ├──demand nofuel.csv
│   ├──demand.csv
│   ├──fuel_prices.csv
│   ├──nodes.csv
│   ├──nodes.json
│   └──time_data.json
│ 
├── assets
│   ├──beccs_electricity.json
│   ├──beccs_gasoline.json
│   ├──beccs_hydrogen.json
│   ├──beccs_liquid_fuels.json
│   ├──beccs_naturalgas.json
│   ├──co2_injection.json
│   ├──electricdac.json
│   ├──electricity_stor.json
│   ├──electrolyzer.json
│   ├──h2gas_power_ccgt.json
│   ├──h2gas_power_ocgt.json
│   ├──h2pipelines.json
│   ├──h2storage.json
│   ├──hydropower.json
│   ├──liquid_fuels_end_use.json
│   ├──liquid_fuels_fossil_upstream.json
│   ├──mustrun.json
│   ├──natgasdac.json
│   ├──naturalgas_end_use.json
│   ├──naturalgas_fossil_upstream.json
│   ├──naturalgas_h2.json
│   ├──naturalgas_h2_ccs.json
│   ├──naturalgas_power.json
│   ├──naturalgas_power_ccs.json
│   ├──nuclear_power.json
│   ├──powerlines.json
│   ├──synthetic_liquid_fuels.json
│   ├──synthetic_naturalgas.json
│   └──vre.json
├── run.jl
├── run_HiGHS.jl
├── run_with_env.jl
└── system_data.json
```

In this example, `MyCase` will define a case with `assets` like  `beccs_electricity`, `electrolyzer`, `naturalgas_power` etc. resources, the `system` folder will provide the data for the demand, fuel prices, network etc., and the `settings` folder will contain the configuration files for the model.

The `run_HiGHS.jl` file should contain the following code:

```julia
using MacroEnergy

(system, model) = run_case(@__DIR__);
```

which will run the case using the HiGHS solver. To use a different solver, you can pass the Optimizer object as an argument to `run_case` function. For example, to use Gurobi as the solver, you can use the following code (which is what the `run.jl` has):

```julia
using MacroEnergy
using Gurobi

(system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);
```

To run the case, open a terminal and run the following command:

```
$ julia --project="/path/to/env"
julia> include("/path/to/MyCase/run.jl")
```

where `/path/to/env` is the path to the environment with `Macro` installed, and `/path/to/MyCase` is the path to the folder of the `MyCase` case.
Alternatively, you can run the case directly from the terminal using the following command:

```
$ julia --project="/path/to/env" /path/to/MyCase/run.jl
```
