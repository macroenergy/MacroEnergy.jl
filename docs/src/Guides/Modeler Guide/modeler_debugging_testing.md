# Debugging and Testing a Macro Model

```@meta
DocTestSetup = quote
    using MacroEnergy
end
```

Macro offers a range of utility functions designed to make debugging and testing new models and sectors more efficient and straightforward.

The following functions are organized with the following sections:
- [Working with a System](@ref "Working with a System")
- [Generating a Model](@ref "Model Generation and Running")
- [Working with Nodes](@ref "Working with Nodes in a System")
- [Working with Assets](@ref "Working with Assets")
- [Working with Edges](@ref "Working with Edges")
- [Working with Transformations](@ref "Working with Transformations")
- [Working with Storages](@ref "Working with Storages")
- [Time Management](@ref "Time Management")
- [Results Collection and Writing](@ref "Results Collection and Writing")

## Working with a System
Let's start by loading a system from a case folder (you can find more information about the structure of this folder in the [Running Macro](@ref) section).

### `load_case`
```julia
julia> using MacroEnergy
julia> case = MacroEnergy.load_case("doctest");
[ Info: Loading case from doctest/system_data.json
[ Info: Loading system data
[ Info: Done loading system data. It took 0.39 seconds
[ Info: Done loading case data. It took 0.39 seconds
[ Info: *** Generating case ***
[ Info: Configuring case
[ Info:  -- Setting solution algorithm
[ Info:  -- Solution algorithm set to MacroEnergy.Monolithic()
[ Info: Generating systems
[ Info: Generating system
[ Info:  ++ Creating new location: NE
[ Info: Done generating system. It took 9.2 seconds
[ Info:  -- Discounting fixed costs for period 1
[ Info:  -- Computing retirement case for period 1
[ Info: *** Done generating case. It took 10.18 seconds ***
```

### `propertynames`
The `propertynames` function in Julia can be used to retrieve the names of the fields of a `System` object, such as the data directory path, settings, and locations.

```julia
julia> propertynames(system)
(:data_dirpath, :settings, :commodities, :time_data, :assets, :locations, :input_data)
```

- `data_dirpath`: Path to the data directory.
- `settings`: Settings of the system.
- `commodities`: Sectors modeled in the system.
- `timedata`: Time resolution for each sector.
- `locations`: Vector of all `Location`s and `Node`s.
- `assets`: Vector of all `Asset`s.

A `System` consists of six primary fields, each of which can be accessed using dot notation:
```julia
julia> system.data_dirpath
"doctest"
julia> system.settings
(ConstraintScaling = true, WriteSubcommodities = true, OverwriteResults = false, OutputDir = "results", OutputLayout = "long", AutoCreateNodes = false, AutoCreateLocations = true, Retrofitting = false, DualExportsEnabled = true)
```

When interacting with a `System`, users might need to **retrieve information** about specific nodes, locations, or assets. The functions listed below are helpful for these tasks:

### [`find_node`](@ref)
Finds a node by its ID.
```julia
julia> co2_node = MacroEnergy.find_node(system.locations, :co2_sink)
```

### [`get_asset_types`](@ref)
Retrieves all the types of assets in the system.
```julia
julia> asset_types = MacroEnergy.get_asset_types(system);
julia> unique(asset_types)
7-element Vector{DataType}:
 Battery
 Electrolyzer
 GasStorage{Hydrogen}
 ThermalPower{NaturalGas}
 ThermalPower{Uranium}
 TransmissionLink{Electricity}
 VRE
```

### [`asset_ids`](@ref)
Retrieves the IDs of all the assets in the system.
```julia
julia> ids = MacroEnergy.asset_ids(system)
102-element Vector{Symbol}:
 :battery_SE
 :battery_MIDAT
 :battery_NE
 :pumpedhydro_SE
 :pumpedhydro_MIDAT
 :pumpedhydro_NE
 :SE_Electrolyzer
 :MIDAT_Electrolyzer
 :NE_Electrolyzer
 :h2_SE_to_MIDAT
 ⋮
 :existing_solar_MIDAT
 :existing_solar_SE
 :existing_solar_NE
 :existing_wind_NE
 :existing_wind_MIDAT
```
Once you have the IDs, you can retrieve an asset by its ID using the following function:
### [`get_asset_by_id`](@ref)
Retrieves an asset by its ID.
```julia
julia> battery_SE = MacroEnergy.get_asset_by_id(system, :battery_SE);
julia> thermal_plant_SE = MacroEnergy.get_asset_by_id(system, :SE_natural_gas_fired_combined_cycle_1);
```

The following function can be useful to retrieve a vector of all the assets of a given type.
### [`get_assets_sametype`](@ref)
Returns a vector of assets of a given type.
```julia
julia> batteries = MacroEnergy.get_assets_sametype(system, Battery);
julia> battery = batteries[1]; # first battery in the list
julia> thermal_plants = MacroEnergy.get_assets_sametype(system, ThermalPower{NaturalGas});
julia> thermal_plant = thermal_plants[1]; # first thermal power plant in the list
```

## Model Generation and Running

### `create_optimizer`
Create an optimizer given a solver, optionally passing also environment and attributes:
```julia
optimizer = MacroEnergy.create_optimizer(HiGHS.Optimizer)
```

### `generate_model`
Uses JuMP to generate the optimization model for the system data.
```julia
julia> model = MacroEnergy.generate_model(case,optimizer);
[ Info: Generating model
[ Info:  -- Period 1
[ Info:  -- Adding linking variables
[ Info:  -- Defining available capacity
[ Info:  -- Generating planning model
[ Info:  -- Including age-based retirements
[ Info:  -- Generating operational model
[ Info:  -- Model generation complete, it took 8.293462991714478 seconds
```

### `optimize!`
Solves the optimization model.
```julia
julia> MacroEnergy.optimize!(model)
```

The following set of functions can be used to retrieve the optimal values of some variables in the model.
### [`get_optimal_capacity`](@ref)
Fetches the final capacities for all assets.
```julia
julia> capacity = MacroEnergy.get_optimal_capacity(system);
julia> capacity[!, [:commodity, :resource_id, :value]]
102×3 DataFrame
 Row │ commodity    resource_id                        value    
     │ Symbol       Symbol                             Float64  
─────┼──────────────────────────────────────────────────────────
   1 │ Electricity  battery_SE                          7589.08
   2 │ Electricity  battery_MIDAT                       1232.14
   3 │ Electricity  battery_NE                            -0.0
   4 │ Electricity  pumpedhydro_SE                      6261.98
   5 │ Electricity  pumpedhydro_MIDAT                   5244.0
   6 │ Electricity  pumpedhydro_NE                      3206.9
   7 │ Hydrogen     SE_Electrolyzer                    24638.1
   8 │ Hydrogen     MIDAT_Electrolyzer                 38550.8
  ⋮  │      ⋮                       ⋮                     ⋮
  98 │ Electricity  existing_solar_MIDAT                2974.6
  99 │ Electricity  existing_solar_SE                   8502.2
 100 │ Electricity  existing_solar_NE                      0.0
 101 │ Electricity  existing_wind_NE                    3654.5
 102 │ Electricity  existing_wind_MIDAT                 3231.6
                                                 87 rows omitted
```

### [`get_optimal_new_capacity`](@ref)
Fetches the new capacities for all assets.
```julia
julia> new_capacity = MacroEnergy.get_optimal_new_capacity(system);
julia> new_capacity[!, [:commodity, :resource_id, :value]]
102×3 DataFrame
 Row │ commodity    resource_id                        value    
     │ Symbol       Symbol                             Float64  
─────┼──────────────────────────────────────────────────────────
   1 │ Electricity  battery_SE                          7589.08
   2 │ Electricity  battery_MIDAT                       1232.14
   3 │ Electricity  battery_NE                             0.0
   4 │ Electricity  pumpedhydro_SE                         0.0
   5 │ Electricity  pumpedhydro_MIDAT                      0.0
   6 │ Electricity  pumpedhydro_NE                         0.0
   7 │ Hydrogen     SE_Electrolyzer                    24638.1
   8 │ Hydrogen     MIDAT_Electrolyzer                 38550.8
  ⋮  │      ⋮                       ⋮                     ⋮
  98 │ Electricity  existing_solar_MIDAT                   0.0
  99 │ Electricity  existing_solar_SE                      0.0
 100 │ Electricity  existing_solar_NE                      0.0
 101 │ Electricity  existing_wind_NE                       0.0
 102 │ Electricity  existing_wind_MIDAT                    0.0
                                                 87 rows omitted
```

### [`get_optimal_retired_capacity`](@ref)
Fetches the retired capacities for all assets.
```julia
julia> retired_capacity = MacroEnergy.get_optimal_retired_capacity(system);
julia> retired_capacity[!, [:commodity, :resource_id, :value]]
102×3 DataFrame
 Row │ commodity    resource_id                        value   
     │ Symbol       Symbol                             Float64 
─────┼─────────────────────────────────────────────────────────
   1 │ Electricity  battery_SE                             0.0
   2 │ Electricity  battery_MIDAT                          0.0
   3 │ Electricity  battery_NE                             0.0
   4 │ Electricity  pumpedhydro_SE                         0.0
   5 │ Electricity  pumpedhydro_MIDAT                      0.0
   6 │ Electricity  pumpedhydro_NE                         0.0
   7 │ Hydrogen     SE_Electrolyzer                        0.0
   8 │ Hydrogen     MIDAT_Electrolyzer                     0.0
  ⋮  │      ⋮                       ⋮                     ⋮
  98 │ Electricity  existing_solar_MIDAT                   0.0
  99 │ Electricity  existing_solar_SE                      0.0
 100 │ Electricity  existing_solar_NE                   1629.6
 101 │ Electricity  existing_wind_NE                       0.0
 102 │ Electricity  existing_wind_MIDAT                    0.0
                                                87 rows omitted
```

See the [Results Collection and Writing](@ref "Results Collection and Writing") section for more information on how to write the results to a file.

## Working with Nodes in a System
Once a `System` object is loaded, and the model is generated, users can use the following functions to inspect the nodes in the system.

!!! tip "Node Interface"
    For a comprehensive list of function interfaces available for node besides `id`, `commodity_type` and the ones listed below, users can refer to the `node.jl` and the `vertex.jl` source code.

### [`find_node`](@ref)
Finds a node in the `System` by its ID.

```julia
julia> elec_node = MacroEnergy.find_node(system.locations, :elec_SE);
```

!!! note "Understanding Balance Equations"
    Nodes, as explained in the [Macro Internal Components](@ref) section, are a unique type of *vertex* that represent the demand or supply of a commodity, where each vertex in Macro is associated with a **balance equation**.
    To programmatically access all balance equations within the system, the following functions are available:
    - [`balance_ids`](@ref): Retrieve the **IDs** of all balance equations associated with a vertex.
    - [`get_balance`](@ref): Obtain the **mathematical expression** of a specific balance equation.
    - [`balance_data`](@ref): Access the **input balance data**, which typically includes the stoichiometric coefficients of a specific balance equation, if applicable.

Here is an example of how to use these functions to access the balance equations for the electricity node in the system:

### [`balance_ids`](@ref)
Retrieves the IDs of all balance equations in a node.
```julia
julia> MacroEnergy.balance_ids(elec_node)
1-element Vector{Symbol}:
 :demand
```

!!! note "Demand Balance Equation"
    Macro automatically creates a `:demand` balance equation for each node that has a `BalanceConstraint`. 

### [`get_balance`](@ref)
Retrieves the mathematical expression of the demand balance equation for the node.
```julia
julia> demand_expression = MacroEnergy.get_balance(elec_node, :demand);

julia> demand_expression[1] # first time step
-102999 vREF + vNSD_elec_SE_period1[1,1] + vFLOW_battery_SE_discharge_edge_period1[1] - vFLOW_battery_SE_charge_edge_period1[1] + vFLOW_pumpedhydro_SE_discharge_edge_period1[1] - vFLOW_pumpedhydro_SE_charge_edge_period1[1] - vFLOW_SE_Electrolyzer_elec_edge_period1[1] - vFLOW_h2_SE_to_MIDAT_charge_elec_edge_period1[1] - vFLOW_h2_SE_to_MIDAT_discharge_elec_edge_period1[1] + vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1] + vFLOW_SE_naturalgas_ctavgcf_moderate_0_elec_edge_period1[1] + vFLOW_SE_nuclear_2_elec_edge_period1[1] + vFLOW_SE_nuclear_mid_0_elec_edge_period1[1] - vFLOWPOS_SE_to_MIDAT_transmission_edge_period1[1] + vFLOW_SE_landbasedwind_class4_moderate_70_7_edge_period1[1] + vFLOW_SE_landbasedwind_class4_moderate_70_8_edge_period1[1] + vFLOW_existing_solar_SE_edge_period1[1]
```

### [`balance_ids`](@ref)
```julia
julia> co2_node = MacroEnergy.find_node(system.locations, :co2_sink);

julia> MacroEnergy.balance_ids(co2_node)
1-element Vector{Symbol}:
 :emissions
```

!!! note "CO₂ Balance Equation"
    Macro automatically creates an `:emissions` balance equation for each CO₂ node that has a `CO2CapConstraint`.

### [`get_balance`](@ref)
```julia
julia> emissions_expression = MacroEnergy.get_balance(co2_node, :emissions);

julia> emissions_expression[1] # first time step
vFLOW_MIDAT_natural_gas_fired_combined_cycle_1_co2_edge_period1[1] + vFLOW_MIDAT_natural_gas_fired_combined_cycle_2_co2_edge_period1[1] + vFLOW_NE_naturalgas_ctavgcf_moderate_0_co2_edge_period1[1] + vFLOW_SE_nuclear_1_co2_edge_period1[1] + vFLOW_SE_nuclear_2_co2_edge_period1[1] + vFLOW_NE_nuclear_1_co2_edge_period1[1] + vFLOW_NE_nuclear_2_co2_edge_period1[1] + vFLOW_MIDAT_nuclear_1_co2_edge_period1[1] + vFLOW_MIDAT_nuclear_2_co2_edge_period1[1] + vFLOW_MIDAT_nuclear_mid_0_co2_edge_period1[1] + vFLOW_NE_nuclear_mid_0_co2_edge_period1[1] + vFLOW_SE_nuclear_mid_0_co2_edge_period1[1]
```

!!! tip "Total Emissions"
    To calculate the total emissions at a node, users should perform the following steps:
    ```julia
    julia> emissions_expression = MacroEnergy.get_balance(co2_node, :emissions);

    julia> MacroEnergy.value(sum(emissions_expression))
    0.0
    ```

To check and visualize the mathematical expressions of the **constraints** applied to a node, the following functions are available:
- [`all_constraints`](@ref): Retrieve all constraints associated with a node.
- [`all_constraints_types`](@ref): Retrieve all types of constraints associated with a node.
- [`get_constraint_by_type`](@ref): Retrieve a specific constraint on a node by its type.

### [`all_constraints`](@ref)
Retrieves all the constraints attached to a node.
```julia
julia> all_constraints = MacroEnergy.all_constraints(elec_node);
```

### [`all_constraints_types`](@ref)
Retrieves all the types of constraints attached to a node.
```julia
julia> all_constraints_types = MacroEnergy.all_constraints_types(elec_node)
3-element Vector{DataType}:
 MaxNonServedDemandPerSegmentConstraint
 MaxNonServedDemandConstraint
 BalanceConstraint
```

### [`get_constraint_by_type`](@ref), `constraint_ref`
Retrieves a constraint on a node by its type.
```julia
julia> balance_constraint = MacroEnergy.get_constraint_by_type(elec_node, BalanceConstraint);

julia> MacroEnergy.constraint_ref(balance_constraint);

julia> max_non_served_demand_constraint = MacroEnergy.get_constraint_by_type(elec_node, MaxNonServedDemandConstraint);

julia> MacroEnergy.constraint_ref(max_non_served_demand_constraint)[1:5]
1-dimensional DenseAxisArray{JuMP.ConstraintRef,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.ConstraintRef}:
 vNSD_elec_SE_period1[1,1] ≤ 102999
 vNSD_elec_SE_period1[1,2] ≤ 98121
 vNSD_elec_SE_period1[1,3] ≤ 95100
 vNSD_elec_SE_period1[1,4] ≤ 93727
 vNSD_elec_SE_period1[1,5] ≤ 93366
```

## Working with Assets
Together with Locations, assets form the core components of an energy system in Macro. The functions below are essential for managing and interacting with assets.

### `id`
Retrieves the ID of an asset.
```julia
julia> thermal_plant = MacroEnergy.get_asset_by_id(system, :SE_natural_gas_fired_combined_cycle_1);

julia> MacroEnergy.id(thermal_plant)
:SE_natural_gas_fired_combined_cycle_1
```

### [`print_struct_info`](@ref)
Prints the structure of an asset in terms of its components (edges, transformations, storages, etc.)
```julia
julia> MacroEnergy.print_struct_info(thermal_plant)
Field: thermal_transform, Type: Transformation
Field: elec_edge, Type: Union{Edge{<:Electricity}, EdgeWithUC{<:Electricity}}
Field: fuel_edge, Type: Edge{<:NaturalGas}
Field: co2_edge, Type: Edge{<:CO2}
```

Once you have collected the **names** of the components of an asset, you can use the following function to get a specific component by its name.

### [`get_component_by_fieldname`](@ref)
Retrieves a component of an asset by its field name.
```julia
julia> elec_edge = MacroEnergy.get_component_by_fieldname(thermal_plant, :elec_edge);

julia> MacroEnergy.id(elec_edge)
:SE_natural_gas_fired_combined_cycle_1_elec_edge

julia> MacroEnergy.typeof(elec_edge)
EdgeWithUC{Electricity}

julia> MacroEnergy.commodity_type(elec_edge)
Electricity
```

Alternatively, users can retrieve a specific component using its ID.
### [`get_component_ids`](@ref)
Retrieves the IDs of all the components of an asset.
```julia
julia> MacroEnergy.get_component_ids(thermal_plant)
4-element Vector{Symbol}:
 :SE_natural_gas_fired_combined_cycle_1_transforms
 :SE_natural_gas_fired_combined_cycle_1_elec_edge
 :SE_natural_gas_fired_combined_cycle_1_fuel_edge
 :SE_natural_gas_fired_combined_cycle_1_co2_edge
```

### [`get_component_by_id`](@ref)
Retrieves a component of an asset by its ID.
```julia
julia> elec_edge = MacroEnergy.get_component_by_id(thermal_plant, :SE_natural_gas_fired_combined_cycle_1_elec_edge);

julia> MacroEnergy.id(elec_edge)
:SE_natural_gas_fired_combined_cycle_1_elec_edge

julia> MacroEnergy.typeof(elec_edge)
EdgeWithUC{Electricity}
```

## Working with Edges

### `id`
Retrieves the ID of an edge.
```julia
julia> MacroEnergy.id(elec_edge)
:SE_natural_gas_fired_combined_cycle_1_elec_edge
```

### `commodity_type`
Retrieves the commodity type of an edge.
```julia
julia> MacroEnergy.commodity_type(elec_edge)
Electricity
```

!!! tip "Edge Interface"
    For a comprehensive list of function interfaces available for edge besides `id`, `commodity_type` and the ones listed below, users can refer to the `edge.jl` source code.

### [`get_edges`](@ref)
Retrieves all the edges in the system.
```julia
julia> edges = MacroEnergy.get_edges(system);
```

### `capacity`
Retrieves the capacity expression of an edge.
```julia
capacity_expression = MacroEnergy.capacity(elec_edge)
vCAP_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1
```

### `final_capacity`
Retrieves the final capacity of an edge (i.e. the optimal value of the capacity expression).
```julia
julia> capacity_expression = MacroEnergy.capacity(elec_edge)
vCAP_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1

julia> MacroEnergy.value(capacity_expression)
0.0
```

### `flow`
Retrieves the flow variables of an edge.
```julia
julia> flow_variables = MacroEnergy.flow(elec_edge);

julia> flow_variables[1:5]
1-dimensional DenseAxisArray{JuMP.VariableRef,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.VariableRef}:
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[2]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[3]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[4]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[5]
```

### `value`
Retrieves the values of the flow variables of an edge.
```julia
julia> flow_values = MacroEnergy.value.(flow_variables);

julia> flow_values[1:5]
1-dimensional DenseAxisArray{Float64,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{Float64}:
 -0.0
 -0.0
 -0.0
 -0.0
 -0.0
```

!!! note "Broadcasted `value`"
    Note that the `value` function is called with the dot notation to apply it to each element of the `flow_variables` array (see [Julia's documentation](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized) for more information).

In this example, we first get the flow of the CO₂ edge and then we call the `value` function to get the values of these variables.
```julia
julia> co2_edge = MacroEnergy.get_component_by_fieldname(thermal_plant, :co2_edge);

julia> emission = MacroEnergy.flow(co2_edge)[1:5]
1-dimensional DenseAxisArray{JuMP.VariableRef,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.VariableRef}:
 vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[1]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[2]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[3]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[4]
 vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[5]

julia> emission_values = MacroEnergy.value.(emission);

julia> emission_values[1:5]
1-dimensional DenseAxisArray{Float64,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{Float64}:
 0.0
 0.0
 0.0
 0.0
 0.0
```

The functions available for nodes when dealing with constraints can also be used for edges.

### [`all_constraints_types`](@ref)
```julia
julia> MacroEnergy.all_constraints_types(elec_edge)
5-element Vector{DataType}:
 MinFlowConstraint
 MinDownTimeConstraint
 CapacityConstraint
 MinUpTimeConstraint
 RampingLimitConstraint
```

### [`get_constraint_by_type`](@ref)
```julia
julia> constraint = MacroEnergy.get_constraint_by_type(elec_edge, CapacityConstraint);

julia> MacroEnergy.constraint_ref(constraint)[1:5]
1-dimensional DenseAxisArray{JuMP.ConstraintRef,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.ConstraintRef}:
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1] - 504.206 vCOMMIT_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1] ≤ 0
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[2] - 504.206 vCOMMIT_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[2] ≤ 0
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[3] - 504.206 vCOMMIT_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[3] ≤ 0
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[4] - 504.206 vCOMMIT_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[4] ≤ 0
 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[5] - 504.206 vCOMMIT_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[5] ≤ 0
```

### `start_vertex`
Retrieves the starting node of an edge.
```julia
julia> start_node = MacroEnergy.start_vertex(elec_edge);

julia> MacroEnergy.id(start_node)
:SE_natural_gas_fired_combined_cycle_1_transforms

julia> MacroEnergy.typeof(start_node)
Transformation
```

### `end_vertex`
Retrieves the ending node of an edge.
```julia
julia> end_node = MacroEnergy.end_vertex(elec_edge);

julia> MacroEnergy.id(end_node)
:elec_SE

julia> MacroEnergy.typeof(end_node)
Node{Electricity}
```

## Working with Transformations

!!! tip "Transformation Interface"
    For a comprehensive list of function interfaces available for transformation besides `id`, `commodity_type` and the ones listed below, users can refer to the `transformation.jl` and the `vertex.jl` source code.

To access the transformation component of an asset, utilize the following functions:
```julia
julia> MacroEnergy.print_struct_info(thermal_plant)
Field: thermal_transform, Type: Transformation
Field: elec_edge, Type: Union{Edge{<:Electricity}, EdgeWithUC{<:Electricity}}
Field: fuel_edge, Type: Edge{<:NaturalGas}
Field: co2_edge, Type: Edge{<:CO2}

julia> thermal_transform = MacroEnergy.get_component_by_fieldname(thermal_plant, :thermal_transform);

julia> MacroEnergy.id(thermal_transform)
:SE_natural_gas_fired_combined_cycle_1_transforms

julia> MacroEnergy.typeof(thermal_transform)
Transformation
```

### [`balance_ids`](@ref)
Retrieves the IDs of all the balance equations in a transformation.
```julia
julia> MacroEnergy.balance_ids(thermal_transform)
2-element Vector{Symbol}:
 :emissions
 :energy
```

### [`balance_data`](@ref)
Retrieves the balance data of a transformation. This is very useful to check the **stoichiometric coefficients** of a transformation.
```julia
julia> MacroEnergy.balance_data(thermal_transform, :energy)
Dict{Symbol, Float64} with 3 entries:
  :SE_natural_gas_fired_combined_cycle_1_fuel_edge => 1.0
  :SE_natural_gas_fired_combined_cycle_1_elec_edge => 2.13209
  :SE_natural_gas_fired_combined_cycle_1_co2_edge  => 0.0
```

### [`get_balance`](@ref)
Retrieves the mathematical expression of the balance of a transformation.
```julia
julia> MacroEnergy.get_balance(thermal_transform, :energy)[1:5]
1-dimensional DenseAxisArray{JuMP.AffExpr,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.AffExpr}:
 -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[1]
 -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[2] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[2] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[2]
 -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[3] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[3] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[3]
 -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[4] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[4] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[4]
 -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[5] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[5] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[5]
```

We can do the same for the emissions balance equation.
### [`balance_data`](@ref)
```julia
julia> MacroEnergy.balance_data(thermal_transform, :emissions)
Dict{Symbol, Float64} with 3 entries:
  :SE_natural_gas_fired_combined_cycle_1_fuel_edge => 0.181048
  :SE_natural_gas_fired_combined_cycle_1_elec_edge => 0.0
  :SE_natural_gas_fired_combined_cycle_1_co2_edge  => 1.0
```

### [`get_balance`](@ref)
```julia
julia> MacroEnergy.get_balance(thermal_transform, :emissions)[1:5]
1-dimensional DenseAxisArray{JuMP.AffExpr,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.AffExpr}:
 0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[1] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[1]
 0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[2] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[2]
 0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[3] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[3]
 0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[4] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[4]
 0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[5] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[5]
```

The functions available for nodes and edges can also be applied to transformations.
### [`all_constraints`](@ref)
```julia
julia> MacroEnergy.all_constraints(thermal_transform)
1-element Vector{AbstractTypeConstraint}:
 BalanceConstraint(missing, missing, 2-dimensional DenseAxisArray{JuMP.ConstraintRef,2,...} with index sets:
    Dimension 1, [:emissions, :energy]
    Dimension 2, 1:1:24
And data, a 2×24 Matrix{JuMP.ConstraintRef}:
 0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[1] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[1] = 0                                                                                  …  0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[24] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[24] = 0
 -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[1] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[1] = 0     -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[24] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[24] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[24] = 0)
```

### [`all_constraints_types`](@ref)
```julia
julia> MacroEnergy.all_constraints_types(thermal_transform)
1-element Vector{DataType}:
 BalanceConstraint
```

### [`get_constraint_by_type`](@ref)
```julia
julia> MacroEnergy.get_constraint_by_type(thermal_transform, BalanceConstraint)
BalanceConstraint(missing, missing, 2-dimensional DenseAxisArray{JuMP.ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, JuMP.ScalarShape},2,...} with index sets:
    Dimension 1, [:emissions, :energy]
    Dimension 2, 1:1:24
And data, a 2×24 Matrix{JuMP.ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, JuMP.ScalarShape}}:
 0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[1] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[1] = …  0.181048235160161 vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[24] - vFLOW_SE_natural_gas_fired_combined_cycle_1_co2_edge_period1[24] = 0
 -2.132092034 vFLOW_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[24] - 295.53638384084 vSTART_SE_natural_gas_fired_combined_cycle_1_elec_edge_period1[24] + vFLOW_SE_natural_gas_fired_combined_cycle_1_fuel_edge_period1[24] = 0)
```

## Working with Storages

!!! tip "Storage Interface"
    For a comprehensive list of function interfaces available for storage besides `id`, `commodity_type` and the ones listed below, users can refer to the `storage.jl` and the `vertex.jl` source code.

To access the storage component of an asset, utilize the following functions:
```julia
julia> battery = MacroEnergy.get_asset_by_id(system, :battery_SE);

julia> MacroEnergy.print_struct_info(battery)
Field: battery_storage, Type: AbstractStorage{<:Electricity}
Field: discharge_edge, Type: Edge{<:Electricity}
Field: charge_edge, Type: Edge{<:Electricity}

julia> storage = MacroEnergy.get_component_by_fieldname(battery, :battery_storage);

julia> MacroEnergy.id(storage)
:battery_SE_storage

julia> MacroEnergy.typeof(storage)
Storage{Electricity}
```

### [`balance_ids`](@ref)
Retrieves the IDs of all the balance equations in a storage.
```julia
julia> MacroEnergy.balance_ids(storage)
1-element Vector{Symbol}:
 :storage
```

### [`balance_data`](@ref)
Retrieves the balance data of a storage. This is very useful to check the **stoichiometric coefficients** of a storage.
```julia
julia> MacroEnergy.balance_data(storage, :storage)
Dict{Symbol, Float64} with 2 entries:
  :battery_SE_discharge_edge => 1.08696
  :battery_SE_charge_edge    => 0.92
```

### [`get_balance`](@ref)
Retrieves the mathematical expression of the balance of a storage.
```julia
julia> MacroEnergy.get_balance(storage, :storage)[1:5]
1-dimensional DenseAxisArray{JuMP.AffExpr,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.AffExpr}:
 -vSTOR_battery_SE_storage_period1[1] + vSTOR_battery_SE_storage_period1[12] - 1.0869565217391304 vFLOW_battery_SE_discharge_edge_period1[1] + 0.92 vFLOW_battery_SE_charge_edge_period1[1]
 -vSTOR_battery_SE_storage_period1[2] + vSTOR_battery_SE_storage_period1[1] - 1.0869565217391304 vFLOW_battery_SE_discharge_edge_period1[2] + 0.92 vFLOW_battery_SE_charge_edge_period1[2]
 -vSTOR_battery_SE_storage_period1[3] + vSTOR_battery_SE_storage_period1[2] - 1.0869565217391304 vFLOW_battery_SE_discharge_edge_period1[3] + 0.92 vFLOW_battery_SE_charge_edge_period1[3]
 -vSTOR_battery_SE_storage_period1[4] + vSTOR_battery_SE_storage_period1[3] - 1.0869565217391304 vFLOW_battery_SE_discharge_edge_period1[4] + 0.92 vFLOW_battery_SE_charge_edge_period1[4]
 -vSTOR_battery_SE_storage_period1[5] + vSTOR_battery_SE_storage_period1[4] - 1.0869565217391304 vFLOW_battery_SE_discharge_edge_period1[5] + 0.92 vFLOW_battery_SE_charge_edge_period1[5]
```

The same set of functions that we have seen for nodes, edges, and transformations are also available for storages.
### [`all_constraints_types`](@ref)
```julia
julia> MacroEnergy.all_constraints_types(storage)
5-element Vector{DataType}:
 StorageMinDurationConstraint
 StorageCapacityConstraint
 StorageMaxDurationConstraint
 StorageSymmetricCapacityConstraint
 BalanceConstraint
```

### [`get_constraint_by_type`](@ref)
```julia
julia> MacroEnergy.get_constraint_by_type(storage, BalanceConstraint)
BalanceConstraint(missing, missing, 2-dimensional DenseAxisArray{JuMP.ConstraintRef,2,...} with index sets:
    Dimension 1, [:storage]
    Dimension 2, 1:1:24
And data, a 1×24 Matrix{JuMP.ConstraintRef}:
 -vSTOR_battery_SE_storage_period1[1] + vSTOR_battery_SE_storage_period1[12] - 1.0869565217391304 vFLOW_battery_SE_discharge_edge_period1[1] + 0.92 vFLOW_battery_SE_charge_edge_period1[1] = 0  …  vSTOR_battery_SE_storage_period1[23] - vSTOR_battery_SE_storage_period1[24] - 1.0869565217391304 vFLOW_battery_SE_discharge_edge_period1[24] + 0.92 vFLOW_battery_SE_charge_edge_period1[24] = 0)

julia> constraint = MacroEnergy.get_constraint_by_type(storage, StorageCapacityConstraint);

julia> MacroEnergy.constraint_ref(constraint)[1:5]
1-dimensional DenseAxisArray{JuMP.ConstraintRef,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{JuMP.ConstraintRef}:
 -vCAP_battery_SE_storage_period1 + vSTOR_battery_SE_storage_period1[1] ≤ 0
 -vCAP_battery_SE_storage_period1 + vSTOR_battery_SE_storage_period1[2] ≤ 0
 -vCAP_battery_SE_storage_period1 + vSTOR_battery_SE_storage_period1[3] ≤ 0
 -vCAP_battery_SE_storage_period1 + vSTOR_battery_SE_storage_period1[4] ≤ 0
 -vCAP_battery_SE_storage_period1 + vSTOR_battery_SE_storage_period1[5] ≤ 0
```

### `storage_level`
Retrieves the storage level variables of a storage component.
```julia
julia> storage_level = MacroEnergy.storage_level(storage);

julia> MacroEnergy.value.(storage_level)[1:5]
1-dimensional DenseAxisArray{Float64,1,...} with index sets:
    Dimension 1, [1, 2, 3, 4, 5]
And data, a 5-element Vector{Float64}:
 -0.0
 -0.0
 -0.0
 -0.0
 -0.0
```

### `charge_edge`
Retrieves the charge edge connected to a storage component.
```julia
julia> charge_edge = MacroEnergy.charge_edge(storage);

julia> MacroEnergy.id(charge_edge)
:battery_SE_charge_edge

julia> MacroEnergy.typeof(charge_edge)
Edge{Electricity}
```

### `discharge_edge`
Retrieves the discharge edge connected to a storage component.
```julia
julia> discharge_edge = MacroEnergy.discharge_edge(storage);

julia> MacroEnergy.id(discharge_edge)
:battery_SE_discharge_edge

julia> MacroEnergy.typeof(discharge_edge)
Edge{Electricity}
```

### `spillage_edge`
Retrieves the spillage edge connected to a storage component (applicable to hydro reservoirs).
```julia
julia> MacroEnergy.spillage_edge(storage)
```

## Time Management
```julia
julia> vertex = MacroEnergy.find_node(system.locations, :elec_SE);

julia> edge = MacroEnergy.get_component_by_fieldname(thermal_plant, :elec_edge);
```

### `time_interval`
Retrieves the time interval of a vertex/edge.
```julia
julia> MacroEnergy.time_interval(vertex)
1:1:24

julia> MacroEnergy.time_interval(edge)
1:1:24
```

### `period_map`
Retrieves the period map of a vertex/edge.
```julia
julia> MacroEnergy.subperiod_map(vertex)
Dict{Int64, Int64} with 2 entries:
  2 => 2
  1 => 1
```

### `modeled_subperiods`
Retrieves the modeled subperiods of a vertex/edge.
```julia
julia> MacroEnergy.modeled_subperiods(vertex)
2-element Vector{Int64}:
 1
 2
```

### `current_subperiod`
Retrieves the subperiod a given time step belongs to for the time series attached to a given vertex/edge.

```julia
julia> MacroEnergy.current_subperiod(vertex, 7)
1
```

### `subperiods`
Retrieves the subperiods of the time series attached to a vertex/edge.
```julia
julia> MacroEnergy.subperiods(vertex)
2-element Vector{StepRange{Int64, Int64}}:
 1:1:12
 13:1:24
```

### `subperiod_indices`
Retrieves the indices of the subperiods of the time series attached to a vertex/edge.
```julia
julia> MacroEnergy.subperiod_indices(vertex)
2-element Vector{Int64}:
 1
 2
```

### `get_subperiod`
Retrieves the subperiod of a vertex/edge for a given index.
```julia
julia> MacroEnergy.get_subperiod(vertex, 2)
13:1:24
```

### `subperiod_weight`
Retrieves the weight of a subperiod of a vertex/edge for a given index.
```julia
julia> MacroEnergy.subperiod_weight(vertex, 2)
365.0
```

## Results Collection and Writing

### [`reshape_wide`](@ref)
Reshapes the results to wide format.
```julia
julia> capacity_results = MacroEnergy.get_optimal_capacity(system; scaling=1e3);

julia> new_capacity_results = MacroEnergy.get_optimal_new_capacity(system; scaling=1e3);

julia> retired_capacity_results = MacroEnergy.get_optimal_retired_capacity(system; scaling=1e3);

julia> all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results);

julia> df_wide = MacroEnergy.reshape_wide(all_capacity_results);

julia> df_wide[1:5, [:commodity, :resource_id, :capacity, :new_capacity, :retired_capacity]]
5×5 DataFrame
 Row │ commodity    resource_id        capacity    new_capacity  retired_capac ⋯
     │ Symbol       Symbol             Float64?    Float64?      Float64?      ⋯
─────┼──────────────────────────────────────────────────────────────────────────
   1 │ Electricity  battery_SE          7.58908e6     7.58908e6                ⋯
   2 │ Electricity  battery_MIDAT       1.23214e6     1.23214e6
   3 │ Electricity  battery_NE         -0.0           0.0
   4 │ Electricity  pumpedhydro_SE      6.26198e6     0.0
   5 │ Electricity  pumpedhydro_MIDAT   5.244e6       0.0                      ⋯
                                                                1 column omitted
```

### [`write_flow`](@ref)
Writes the flow results to a (CSV, CSV.GZ, or Parquet) file. An optional `commodity` and `asset` type filter can be applied.
```julia
julia> write_flow("flow.csv", system)
# Filter by commodity: write only the flow of edges of commodity "Electricity"
julia> write_flow("flow.csv", system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
julia> write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower")
# Filter by commodity and asset type using wildcard matching
julia> write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower*")
```

### [`write_capacity`](@ref)
Writes the capacity results to a (CSV, CSV.GZ, or Parquet) file. An optional `commodity` and `asset` type filter can be applied.
```julia
julia> write_capacity("capacity.csv", system)
# Filter by commodity: write only the capacity of edges of commodity "Electricity"
julia> write_capacity("capacity.csv", system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
julia> write_capacity("capacity.csv", system, asset_type="ThermalPower")
# Filter by asset type using wildcard matching
julia> write_capacity("capacity.csv", system, asset_type="ThermalPower*")
# Filter by commodity and asset type
julia> write_capacity("capacity.csv", system, commodity="Electricity", asset_type=["ThermalPower", "Battery"])
```

### [`write_costs`](@ref)

Writes the costs results to a (CSV, CSV.GZ, or Parquet) file. An optional `type` filter can be applied.

```julia
julia> write_costs("costs.csv", system, model)
```

### [`write_settings`](@ref)

```julia
julia> write_settings(case, "settings.json")
```
This function exports case and system settings to a JSON file, useful for debugging and documentation.

```@meta
DocTestSetup = nothing
```