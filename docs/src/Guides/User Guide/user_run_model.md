# [Running a Macro Model](@id user_run_model)

This guide covers different approaches to running Macro models, from the simplest one-liner to fully customized run scripts that enable parameter sweeps and batch processing in parallel. For more examples of how to run Macro models using *run scripts*, please refer to the [MacroEnergyExamples](https://github.com/macroenergy/MacroEnergyExamples.jl) repository.

## Using the [`run_case`](@ref)

The simplest way to run a Macro model is by writing a very simple `run.jl` script that uses the [`run_case`](@ref) function. This function handles all the steps needed to load, solve, and write results for your case. Make sure to check the [Available Options](@ref) section for the available parameters and how to use them. 

### Basic Usage (no Benders decomposition, with open source solver HiGHS)

Create a file called `run.jl` in your case directory with the following content:

```julia
using MacroEnergy

(systems, solution) = run_case(@__DIR__);
```

The `@__DIR__` macro automatically expands to the directory containing the script, making the script portable.

Once the script is written, you can run it by executing the following command in the terminal:

```bash
$ julia --project=<path/to/your/environment> <path/to/your/case>/run.jl
```

where `<path/to/your/environment>` is the path to the environment with `Macro` installed, and `<path/to/your/case>` is the path to the folder of the case you want to run.

### Customizing the Optimizer (no Benders decomposition)

By default, `run_case` uses the HiGHS optimizer. To use a different solver like Gurobi, you can pass the Optimizer object as an argument to the `run_case` function together with solver-specific settings:

```julia
using MacroEnergy
using Gurobi # or CPLEX, etc.

(systems, solution) = run_case(
    @__DIR__;
    optimizer=Gurobi.Optimizer, # Optimizer Constructor
    optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3), # Optimizer Settings
);
```

For more information about the available solvers and their settings, please refer to the JuMP documentation or the solver's documentation.

### Stop-and-go myopic iteration

By default, Macro solves the model with perfect foresight (either monolithically or applying Benders decomposition). When the `SolutionAlgorithm` setting is set to `"Myopic"`, Macro will run a myopic algorithm where each planning period is optimized individually, and planning decisions are carried over from one period to to the next. Because of time or memory constraints, the user may choose to stop the myopic iterations after a certain period, and start them again at a later stage (for example, in a different job on a computer cluster). This is done by adding to the `case_settings.json` file:

```julia
"MyopicSettings": {
        "Restart": {
            "enabled": true,
            "folder": "results",
            "from_period": 2
        },
        "StopAfterPeriod": 3
    }
```julia

With the above settings, Macro will start the myopic iteration from period 2, loading planning solutions for period 1 from folder "results" and it will terminate the iterations after period 3 has been solved.

### Benders decomposition

To run a case with Benders decomposition, users need to specify the optimizer for the planning problem and the subproblems.

Create a file called `run.jl` in your case directory with the following content (for HiGHS with IPM solver):

```julia
using MacroEnergy
using HiGHS

(systems, solution) = run_case(
    @__DIR__;
    planning_optimizer=HiGHS.Optimizer, # Optimizer Constructor for the planning problem
    subproblem_optimizer=HiGHS.Optimizer, # Optimizer Constructor for the subproblems
    planning_optimizer_attributes=("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3), # Optimizer Settings for the planning problem
    subproblem_optimizer_attributes=("solver" => "ipm", "run_crossover" => "on", "ipm_optimality_tolerance" => 1e-3), # Optimizer Settings for the subproblems
);
```

For Gurobi:
```julia
using MacroEnergy
using Gurobi # or HiGHS, CPLEX, etc.

(systems, solution) = run_case(
    @__DIR__;
    planning_optimizer=Gurobi.Optimizer, # Optimizer Constructor for the planning problem
    subproblem_optimizer=Gurobi.Optimizer, # Optimizer Constructor for the subproblems
    planning_optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3), # Optimizer Settings for the planning problem
    subproblem_optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3), # Optimizer Settings for the subproblems
);
```

Run the script above in a terminal with the usual command:

```bash
$ julia --project=<path/to/your/environment> <path/to/your/case>/run.jl
```

where `<path/to/your/environment>` is the path to the environment with `Macro` installed, and `<path/to/your/case>` is the path to the folder of the case you want to run.

### Available Options

The `run_case` function accepts several optional parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `lazy_load` | Bool | `true` | Whether to delay loading the input data until needed |
| `log_level` | LogLevel | `Logging.Info` | Used to control the amount of information logged to the console and file (import the `Logging` module to change this parameter) |
| `log_to_console` | Bool | `true` | Print log messages to console |
| `log_to_file` | Bool | `true` | Write log messages to file |
| `log_file_path` | String | `"<case_name>.log"` | Path to log file |
| `optimizer` | DataType | `HiGHS.Optimizer` | Optimizer to use (import the solver module to use it) |
| `optimizer_attributes` | Tuple | See below | Solver-specific settings |
| `planning_optimizer` | DataType | `HiGHS.Optimizer` | Optimizer to use for the planning problem (import the solver module to use it) |
| `subproblem_optimizer` | DataType | `HiGHS.Optimizer` | Optimizer to use for the subproblems (import the solver module to use it) |
| `planning_optimizer_attributes` | Tuple | See below | Solver-specific settings for the planning problem |
| `subproblem_optimizer_attributes` | Tuple | See below | Solver-specific settings for the subproblems |

Default optimizer attributes:
```julia
("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2)
```

## Writing Custom Run Scripts

For more control over the workflow, users can write custom run scripts that explicitly call each step. This approach is useful when you need to:

- Run the same model with different parameter values;
- Customize the output writing process;
- Inspect or modify the case before solving;
- Access intermediate results.

Here is an example of a custom run script that loads the case, creates the optimizer, solves the case, and writes the results. Let's create a file called `run_custom.jl` in your case directory with the following content (make sure to replace the `case_path` with the path to your case):

```julia
using MacroEnergy
using HiGHS  # or Gurobi, CPLEX, etc.

# Define the case path
case_path = "path/to/your/case"

# Step 1: Load the case
# Note 1: the semicolon at the end of the line is used to suppress the output (recommended)
# Note 2: the case is loaded lazily by default
case = load_case(case_path);

# Step 2: Create the optimizer
optimizer = create_optimizer(
    HiGHS.Optimizer,
    nothing,  # optional optimizer environment
    ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
)

# Step 3: Solve the case
(case, solution) = solve_case(case, optimizer);

# Step 4: Write results 
# Note: if Myopic, this step is not needed as outputs are written during iteration to reduce memory usage
results_dir = joinpath(case_path, "results")
mkpath(results_dir)

write_outputs(results_dir, case, solution);
```

To use Gurobi as the optimizer, simply replace the following lines:
```julia
using HiGHS

optimizer = create_optimizer(
    HiGHS.Optimizer,
    nothing,  # optional optimizer environment
    ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
)
```
with:

```julia
using Gurobi

optimizer = create_optimizer(
    Gurobi.Optimizer,
    nothing,  # optional optimizer environment
    ("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2)
)
```

To run the script, you can execute a similar command to the one used in the [Basic Usage (no Benders decomposition, with open source solver HiGHS)](@ref) section:

```bash
$ julia --project=<path/to/your/environment> <path/to/your/case>/run_custom.jl
```

where `<path/to/your/environment>` is the path to the environment with `Macro` installed, and `<path/to/your/case>` is the path to the folder of the case you want to run.

## Running Multiple Cases

Users can run multiple cases sequentially or in parallel from a single script. This is useful for comparing different scenarios or configurations.

### Sequential Case Runs

Here is an example of a script (`run_sequential.jl`) that runs multiple cases sequentially and saves the results for later comparison (make sure to replace the `case_paths` with the paths to your cases):

```julia
using MacroEnergy
using HiGHS

# Define paths to multiple cases
case_paths = [
    "examples/case_A",
    "examples/case_B",
    "examples/case_C"
]

# Run the cases sequentially
for case_path in case_paths
    println("Running case: $case_path")
    
    (systems, solution) = run_case(
        case_path;
        optimizer=HiGHS.Optimizer
    )
    
end
```

Run the script above in a terminal with the usual command:

```bash
$ julia --project=<path/to/your/environment> <path/to/your/case>/run_sequential.jl
```

where `<path/to/your/environment>` is the path to the environment with `Macro` installed, and `<path/to/your/case>` is the path to the folder of the case you want to run.

### Parallel Case Runs

For independent cases, users can use Julia's parallel processing to run the cases in parallel. Here is a simple example of a script (`run_parallel.jl`) that runs the cases in parallel using four processes:

```julia
using Distributed
addprocs(4)  # Add 4 worker processes

@everywhere using MacroEnergy
@everywhere using HiGHS

case_paths = ["case_A", "case_B", "case_C", "case_D"]

@everywhere function run_single_case(case_path)
    case = load_case(case_path);
    optimizer = create_optimizer(
        HiGHS.Optimizer,
        nothing,
        ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
    );
    (case, solution) = solve_case(case, optimizer);
    results_dir = joinpath(case_path, "results");
    mkpath(results_dir);
    write_outputs(results_dir, case, solution);
    return nothing
end

pmap(run_single_case, case_paths)
```

The `pmap` function is used to run the `run_single_case` function in parallel on the worker processes and write the results to the `results` directory in each case.

Moreover, the user can customize the `run_single_case` function to add additional processing or post-processing of the results.

## Parameter Sweeps

A common use case is running the same model with different parameter values, such as varying technology costs or policy constraints.

### Modifying Asset Parameters

To modify asset parameters before solving, users can use the following custom workflow:

```julia
using MacroEnergy
using HiGHS

case_path = "path/to/your/case"

# Define investment cost values to sweep
investment_costs = [100_000, 150_000, 200_000, 250_000]  # $/MW

for cost in investment_costs
    println("Running with investment cost: $cost")
    
    # Load a fresh case for each run
    case = load_case(case_path);
    system = case.systems[1];
    
    # Get the asset and modify its cost
    solar = get_asset_by_id(system, :solar_SE)
    solar.edge.investment_cost = cost
    
    # Create optimizer and solve
    optimizer = create_optimizer(
        HiGHS.Optimizer, 
        nothing, 
        # optional optimizer environment
        ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
    );
    (case, solution) = solve_case(case, optimizer);
    
    # Write results to a unique directory
    results_dir = joinpath(case_path, "results_investment_cost_$(cost)")
    mkpath(results_dir);
    write_outputs(results_dir, case, solution);
end
```

For detailed information about how to access and modify the system components, see the [Macro Asset Library](@ref).

Users can also modify the script above to extract and compare key metrics across the cases. Here is an example of how to do this:

```julia
using MacroEnergy
using HiGHS
using DataFrames
using JuMP

case_path = "path/to/your/case"

# Define investment cost values to sweep
investment_costs = [100_000, 150_000, 200_000, 250_000]  # $/MW

# Create a dictionary to store the results
results = Dict{Float64, Any}()

for cost in investment_costs
    println("Running with investment cost: $cost")
    
    # Load a fresh case for each run
    case = load_case(case_path);
    system = case.systems[1];
    
    # Get the asset and modify its cost
    solar = get_asset_by_id(system, :solar_SE)
    solar.edge.investment_cost = cost
    
    # Create optimizer and solve
    optimizer = create_optimizer(
        HiGHS.Optimizer, 
        nothing, 
        # optional optimizer environment
        ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
    );
    (case, solution) = solve_case(case, optimizer);
    
    # Store results
    results[cost] = (case=case, solution=solution)
    
    # Optionally write results to a unique directory
    results_dir = joinpath(case_path, "results_investment_cost_$(cost)")
    mkpath(results_dir)
    write_outputs(results_dir, case, solution)
end

# Create a summary DataFrame
summary = DataFrame(
    investment_cost = Float64[],
    optimal_capacity = Float64[],
    total_cost = Float64[]
)

for (cost, result) in results
    system = result.case.systems[1]
    model = result.solution
    
    # Get optimal capacity for the asset
    solar = get_asset_by_id(system, :solar_SE)
    capacity = value(solar.edge.capacity)
    
    # Get total system cost
    total_cost = objective_value(model)
    
    push!(summary, (cost, capacity, total_cost))
end

sort!(summary, :investment_cost);
println(summary)
```

### Multi-Parameter Sweeps

Similarly, users can modify the script above to sweep multiple parameters simultaneously:

```julia
using MacroEnergy
using HiGHS
using Iterators

case_path = "path/to/your/case"

# Define parameter ranges
solar_investment_costs = [100_000, 200_000, 300_000]
battery_investment_costs = [50_000, 100_000, 150_000]

# Create all combinations
param_combinations = collect(Iterators.product(solar_investment_costs, battery_investment_costs))

results = Dict{Tuple{Float64, Float64}, Any}()

for (solar_investment_cost, battery_investment_cost) in param_combinations
    println("Solar: $solar_investment_cost, Battery: $battery_investment_cost")
    
    case = load_case(case_path);
    system = case.systems[1];
    
    # Modify solar cost
    solar = get_asset_by_id(system, :solar_SE)
    solar.edge.investment_cost = solar_investment_cost
    
    # Modify battery cost
    battery = get_asset_by_id(system, :battery_SE)
    battery.discharge_edge.investment_cost = battery_investment_cost
    
    # Solve
    optimizer = create_optimizer(HiGHS.Optimizer, nothing, ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3));
    (case, solution) = solve_case(case, optimizer);
    
    results[(solar_investment_cost, battery_investment_cost)] = (case=case, solution=solution)
end

# Post-process the results as needed ...
```

## Best Practices

### Memory Management

When running many cases, be mindful of memory usage:

```julia
for case_path in case_paths
    # Run case
    (systems, _) = run_case(case_path)
    
    # Extract and save only what you need
    save_key_results(systems, case_path);
end
```

### Logging

For batch runs, consider adjusting logging to avoid excessive output:

```julia
using Logging

(systems, solution) = run_case(
    case_path;
    log_to_console=false,  # Suppress console output
    log_to_file=true,      # Keep file logging
    log_level=Logging.Warn # Only log warnings and errors
);
```

### Error Handling

Wrap runs in try-catch blocks for robustness when running multiple cases:

```julia
for case_path in case_paths
    try
        (systems, solution) = run_case(case_path)
        println("Successfully completed: $case_path")
    catch e
        println("Failed: $case_path")
        println("Error: $e")
        continue
    end
end
```

## Running Macro Models in an Interactive Julia REPL
All the examples above can be executed line by line in an interactive Julia REPL. This is particularly useful for debugging and testing the model. Please check the [Suggested Development Workflow](@ref) and the [Debugging and Testing a Macro Model](@ref) sections for more information.

!!! tip "Interactive Julia REPL"
    In Julia, when running the same script multiple times, it is recommended to exectute commands or script in an **interactive REPL** (REPL stands for Read-Eval-Print Loop, and it's the command line interface that starts when you type `julia` in the terminal) instead of running the script directly from the terminal. This is because Julia's JIT (Just-In-Time) compiler will compile the code the first time it is run, and subsequent runs will be much faster as the compiled code is cached. Also, the REPL maintains all variables in memory, making it easier to:
    - Inspect variable values;
    - Modify and re-run code without restarting the entire program;
    - Test small code snippets in isolation.

    To open the REPL, open a terminal and type `julia` to start the REPL:

    ```bash
    $ julia
    ```

    This will open the REPL with the default project environment. To open the REPL with a specific project environment, you can use the following command:

    ```bash
    $ julia --project=<path/to/your/environment>
    ```

    where, for instance, `<path/to/your/environment>` can be the path to the environment with `Macro` installed. For more information about how to create and activate an environment, see the [Working with Environments](https://pkgdocs.julialang.org/v1/environments/) page in the Julia documentation.

### Accessing System Components when Running Macro Models in an Interactive Julia REPL

Macro offers a range of utility functions to access and interact with the system components. Here is an example of how to do this:

First open a Julia REPL with the following command:

```bash
$ julia --project=<path/to/your/environment>
```

where, for instance, `<path/to/your/environment>` can be the path to the environment with `Macro` installed. 

Then, in the REPL, type the following commands:

```julia
using MacroEnergy

# Define the case path
case_path = "path/to/your/case"

# Load the case
case = load_case(case_path);

# Access the first system (period)
system = case.systems[1];

# List all asset IDs
asset_ids(system)

# Get a specific asset by ID
battery = get_asset_by_id(system, :battery_SE);

# Get all assets of a specific type
thermal_plants = get_assets_sametype(system, ThermalPower{NaturalGas});

# Access system locations
location_ids(system)

# Other utility functions...
```

For more information about how to interact with the system components, see the [Debugging and Testing a Macro Model](@ref) section.

## See Also

- [Debugging and Testing a Macro Model](@ref) - Useful functions for debugging and testing a Macro model
- [Configuring Settings](@ref) - Configure model settings
- [Writing Results to Files](@ref) - Detailed output options
- [Creating a new System](@ref) - Setting up input data