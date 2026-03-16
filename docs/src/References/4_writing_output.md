# Output functions

```@index
Pages = ["4_writing_output.md"]
```

## `get_optimal_capacity`
```@docs
MacroEnergy.get_optimal_capacity
```

## `get_detailed_costs`
```@docs
MacroEnergy.get_detailed_costs
```

## `get_detailed_costs_benders`
```@docs
MacroEnergy.get_detailed_costs_benders
```

## `get_optimal_curtailment`
```@docs
MacroEnergy.get_optimal_curtailment
```

## `get_optimal_discounted_costs`
```@docs
MacroEnergy.get_optimal_discounted_costs
```

## `get_optimal_flow`
```@docs
MacroEnergy.get_optimal_flow
```

## `get_optimal_new_capacity`
```@docs
MacroEnergy.get_optimal_new_capacity
```

## `get_optimal_non_served_demand`
```@docs
MacroEnergy.get_optimal_non_served_demand
```

## `get_optimal_retired_capacity`
```@docs
MacroEnergy.get_optimal_retired_capacity
```

## `get_optimal_storage_level`
```@docs
MacroEnergy.get_optimal_storage_level
```

## `get_optimal_undiscounted_costs`
```@docs
MacroEnergy.get_optimal_undiscounted_costs
```

## `write_balance_duals`
```@docs
MacroEnergy.write_balance_duals
```

## `write_capacity`

```@docs
MacroEnergy.write_capacity
```

## `write_co2_cap_duals`
```@docs
MacroEnergy.write_co2_cap_duals
```

## `write_costs`

```@docs
MacroEnergy.write_costs
```

## `write_curtailment`
```@docs
MacroEnergy.write_curtailment
```

## `write_detailed_costs`
```@docs
MacroEnergy.write_detailed_costs
```

## `write_detailed_costs_benders`
```@docs
MacroEnergy.write_detailed_costs_benders
```

## `write_cost_breakdown_files!`
```@docs
MacroEnergy.write_cost_breakdown_files!
```

## `write_duals`
```@docs
MacroEnergy.write_duals
```

## `write_flow`

```@docs
MacroEnergy.write_flow
```

## `write_non_served_demand`

```@docs
MacroEnergy.write_non_served_demand
```

## `write_settings`

```@docs
MacroEnergy.write_settings
```

## `write_storage_level`

```@docs
MacroEnergy.write_storage_level
```

## `write_undiscounted_costs`
```@docs
MacroEnergy.write_undiscounted_costs
```

## `write_dataframe`
```@docs
MacroEnergy.write_dataframe
```

## `MacroEnergy.write_outputs`
```@docs
MacroEnergy.MacroEnergy.write_outputs
```

## `MacroEnergy.write_outputs_myopic`
```@docs
MacroEnergy.write_outputs_myopic
```

## `MacroEnergy.write_period_outputs`
```@docs
MacroEnergy.MacroEnergy.write_period_outputs
```

# Output utility functions

These helpers support cost aggregation, reshaping, and Benders-specific cost extraction.

## `aggregate_costs_by_type`
```@docs
MacroEnergy.aggregate_costs_by_type
```

## `aggregate_costs_by_zone`
```@docs
MacroEnergy.aggregate_costs_by_zone
```

## `aggregate_operational_costs`
```@docs
MacroEnergy.aggregate_operational_costs
```

## `add_total_row!`
```@docs
MacroEnergy.add_total_row!
```

## `reshape_costs_wide`
```@docs
MacroEnergy.reshape_costs_wide
```

## `get_fixed_costs_benders`
```@docs
MacroEnergy.get_fixed_costs_benders
```

## `mkpath_for_period`
```@docs
MacroEnergy.mkpath_for_period
```

# Cost computation helpers

Low-level functions used by `get_detailed_costs` to compute cost components. Useful for extending or debugging cost logic.

## `compute_investment_cost`
```@docs
MacroEnergy.compute_investment_cost
```

## `compute_fixed_om_cost`
```@docs
MacroEnergy.compute_fixed_om_cost
```

## `compute_variable_om_cost`
```@docs
MacroEnergy.compute_variable_om_cost
```

## `compute_fuel_cost`
```@docs
MacroEnergy.compute_fuel_cost
```

## `compute_startup_cost`
```@docs
MacroEnergy.compute_startup_cost
```

## `compute_nsd_cost`
```@docs
MacroEnergy.compute_nsd_cost
```

## `compute_supply_cost`
```@docs
MacroEnergy.compute_supply_cost
```

## `compute_slack_cost`
```@docs
MacroEnergy.compute_slack_cost
```