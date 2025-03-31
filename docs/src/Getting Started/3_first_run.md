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
To run Macro with a user-defined case, you need to create a folder `MyCase` with the following structure:

```
MyCase
├── assets/
├── dolphyn_data/
├── h2transport_options/
├── settings/
├── system/
├── timeseries_3weeks/
├── timeseries_full_year/
├── run.jl
├── run_HiGHS.jl
├── run_with_env.jl
└── system_data.json
```

where the `assets` folder consists of the details of the configurations of the different resources modeled as assets within Macro (e.g. the location of the nodes, edges, types of resources, such as BECCS, electrolyzers, hydrostorage units etc.), the `dolphyn_data` consists of the `.csv` files for resources, just as before, but to run with DOLPHYN model, the `h2transport_options` folder is similar to the contents of the `assets` folder, but it specifically contains `.json` files for h1 pipelines and transportations. The `settings` folder contains the configuration files for the constraint scaling and writing subcommodities, the `system` folder contains the `.csv` and `.json` input files related to timeseries data and the system under study, the `resource` folder contains the `.csv` input files with the list of generators to include in the model, and the `policies` folder contains the `.csv` input files which define the policies to be included in the model. 
For instance, one case could have the following structure:

```
MyCase
│ 
├── settings
│   ├── genx_settings.yml           # GenX settings
│   ├── [solver_name]_settings.yml  # Solver settings
│   ├── multi_stage_settings.yml    # Multi-stage settings
│   └── time_domain_reduction.yml   # Time-domain clustering settings
│ 
├── system
│   ├── Demand_data.csv
│   ├── Fuel_data.csv
│   ├── Generators_variability.csv
│   └── Network.csv
│ 
├── policies
│   ├── CO2_cap.csv
│   ├── Minimum_capacity_requirement.csv
│   └── Energy_share_requirement.csv
│ 
├── resources
│   ├── Thermal.csv
│   ├── Storage.csv
│   ├── Vre.csv
│   ├── Hydro.csv
│   └── policy_assignments
|       ├── Resource_minimum_capacity_requirement.csv
│       └── Resource_energy_share_requirement.csv
│
└── Run.jl
```

In this example, `MyCase` will define a case with `Themal`, `Storage`, `Vre`, and `Hydro` resources, the `system` folder will provide the data for the demand, fuel, generators' variability, and network, the `policies` folder will include a CO2 cap, a minimum capacity requirement, and an energy share requirement, and the `settings` folder will contain the configuration files for the model. 

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
