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
