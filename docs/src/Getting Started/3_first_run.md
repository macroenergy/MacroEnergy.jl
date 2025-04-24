# Running Macro

Once Macro is installed, the simplest way to get started is to run the example system provided in the `ExampleSystems` folder. It is a system with 3 zones in the eastern US, with the following sectors:
- Electricity
- Natural Gas
- CO2
- Hydrogen
- Biomass
- Uranium
- Carbon Capture

!!! tip "Macro Input Data Description"
    The section [Macro Input Data](@ref) in the [User Guide](@ref) provides a detailed description of all the input files present in the example folder.

To run the example, navigate to the `ExampleSystems/eastern_us_three_zones` folder and execute the `run.jl` file present in the folder:

```bash
cd ExampleSystems/eastern_us_three_zones
julia --project=. run.jl
```

This will use Macro to solve the example system and save the results in the `results` directory. By default, Macro writes three files: 
- `capacity.csv`: a csv file containing the capacity results for each asset (final, newly installed, and retired capacity for each technology).
- `costs.csv`: a csv file containing fixed, variable and total costs for the energy system.
- `flow.csv`: a csv file containing the flow results for each commodity through each edge.

Congratulations, you just ran your first Macro model! 🎉

## Running Macro with user-defined cases
To run Macro with a user-defined case, you need to create a folder `MyCase` with a minimum of the following structure (customized cases can have additional files and folders (refer to the example cases, for specific details)):

```
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

```
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
which will run the case using the HiGHS solver. To use a different solver, you can pass the Optimizer object as an argument to `run_case!` function. For example, to use Gurobi as the solver, you can use the following code (which is what the `run.jl` has):

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
