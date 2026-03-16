# [Non-Benders Utility Functions](@id non-benders-utilities)

```@index
Pages = ["5_utilities.md"]
```

## `all_constraints`
```@docs
MacroEnergy.all_constraints
```

## `all_constraints_types`
```@docs
MacroEnergy.all_constraints_types
```

## `asset_ids`
```@docs
MacroEnergy.asset_ids
```

## `balance_ids`
```@docs
MacroEnergy.balance_ids
```

## `balance_data`
```@docs
MacroEnergy.balance_data
```

## `create_output_path`
```@docs
MacroEnergy.create_output_path
```

## `ensure_duals_available!`
```@docs
MacroEnergy.ensure_duals_available!
```

## `get_asset_by_id`
```@docs
MacroEnergy.get_asset_by_id
```

## `get_assets_sametype`
```@docs
MacroEnergy.get_assets_sametype
```

## `get_asset_types`
```@docs
MacroEnergy.get_asset_types
```

## `get_balance`
```@docs
MacroEnergy.get_balance
```

## `get_constraint_by_type`
```@docs
MacroEnergy.get_constraint_by_type
```

## `get_component_by_fieldname`
```@docs
MacroEnergy.get_component_by_fieldname
```

## `get_component_ids`
```@docs
MacroEnergy.get_component_ids
```

## `get_component_by_id`
```@docs
MacroEnergy.get_component_by_id
```

## `get_edges`
```@docs
MacroEnergy.get_edges
```

## `get_output_layout`
```@docs
MacroEnergy.get_output_layout
```

## `get_value`
```@docs
MacroEnergy.get_value
```

## `get_value_and_keys`
```@docs    
MacroEnergy.get_value_and_keys
```

## `filter_edges_by_asset_type!`
```@docs
MacroEnergy.filter_edges_by_asset_type!
```

## `filter_edges_by_commodity!`
```@docs
MacroEnergy.filter_edges_by_commodity!
```

## `find_available_path`
```@docs
MacroEnergy.find_available_path
```

## `find_node`
```@docs
MacroEnergy.find_node
```

## `id`
```@docs
MacroEnergy.id
```

## `json_to_csv`
```@docs
MacroEnergy.json_to_csv
```

## `location_ids`
```@docs
MacroEnergy.location_ids
```

## `print_struct_info`
```@docs
MacroEnergy.print_struct_info
```

## `reshape_wide`
```@docs
MacroEnergy.reshape_wide
```

## `reshape_long`
```@docs
MacroEnergy.reshape_long
```

## `search_assets`
```@docs
MacroEnergy.search_assets
```

## `search_commodities`
```@docs
MacroEnergy.search_commodities
```

## `set_value`
```@docs
MacroEnergy.set_value
```

## `set_constraint_dual!`
```@docs
MacroEnergy.set_constraint_dual!
```

## `struct_info`
```@docs
MacroEnergy.struct_info
```

## `timestepbefore`
```@docs
MacroEnergy.timestepbefore
```

# Benders Utility Functions

## `SubproblemsData`
```@docs
MacroEnergy.SubproblemsData
```

## `collect_data_from_subproblems`
```@docs
MacroEnergy.collect_data_from_subproblems
```

## `collect_distributed_data`
```@docs
MacroEnergy.collect_distributed_data
```

## `collect_local_data`
```@docs
MacroEnergy.collect_local_data
```

## `extract_subproblem_results`
```@docs
MacroEnergy.extract_subproblem_results
```

## `populate_slack_vars_from_subproblems!`
```@docs
MacroEnergy.populate_slack_vars_from_subproblems!
```

## `collect_distributed_policy_slack_vars`
```@docs
MacroEnergy.collect_distributed_policy_slack_vars
```

## `collect_local_slack_vars`
```@docs
MacroEnergy.collect_local_slack_vars
```

## `merge_distributed_slack_vars_dicts`
```@docs
MacroEnergy.merge_distributed_slack_vars_dicts
```

## `populate_constraint_duals_from_subproblems!`
```@docs
MacroEnergy.populate_constraint_duals_from_subproblems!
```

## `collect_distributed_constraint_duals`
```@docs
MacroEnergy.collect_distributed_constraint_duals
```

## `collect_local_constraint_duals`
```@docs
MacroEnergy.collect_local_constraint_duals(::Vector{<:AbstractDict}, ::Type{MacroEnergy.AbstractTypeConstraint})
MacroEnergy.collect_local_constraint_duals(::Vector{<:AbstractDict}, ::Type{MacroEnergy.BalanceConstraint})
```

## `merge_distributed_balance_duals`
```@docs
MacroEnergy.merge_distributed_balance_duals
```

## `densearray_to_dict`
```@docs
MacroEnergy.densearray_to_dict
```

## `dict_to_densearray`
```@docs
MacroEnergy.dict_to_densearray
```