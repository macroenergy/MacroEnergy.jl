# Constraint Macros

```@docs
MacroEnergy.var"@add_balance"
```

```@docs
MacroEnergy.var"@add_stoichiometric_balance"
```

```@docs
MacroEnergy.var"@add_to_balance"
```

```@docs
MacroEnergy.var"@add_to_storage_balance"
```

```@docs
MacroEnergy.var"@inspect_stoichiometric_balance"
```

## Grouped constraint configuration

```@docs
MacroEnergy.AbstractConstraintConfig
MacroEnergy.AbstractGroupedConstraintConfig
MacroEnergy.GroupConfig
MacroEnergy.GroupSelector
MacroEnergy.MaxCapacityConstraintConfig
MacroEnergy.MinCapacityConstraintConfig
MacroEnergy.MaxNewCapacityConstraintConfig
MacroEnergy.configure_constraint!
MacroEnergy.validate_required_constraint_configs!
MacroEnergy.parse_grouped_constraint_config
MacroEnergy.select_assets
MacroEnergy.build_grouped_capacity_constraints
```

## Grouped capacity constraint methods

```@docs
MacroEnergy.add_model_constraint!(ct::MaxNewCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)
MacroEnergy.add_model_constraint!(ct::MaxCapacityConstraint, system::MacroEnergy.System, model::Model)
MacroEnergy.add_model_constraint!(ct::MaxCapacityConstraint, location::MacroEnergy.Location, model::Model)
MacroEnergy.add_model_constraint!(ct::MinCapacityConstraint, system::MacroEnergy.System, model::Model)
MacroEnergy.add_model_constraint!(ct::MinCapacityConstraint, location::MacroEnergy.Location, model::Model)
MacroEnergy.add_model_constraint!(ct::MaxNewCapacityConstraint, system::MacroEnergy.System, model::Model)
MacroEnergy.add_model_constraint!(ct::MaxNewCapacityConstraint, location::MacroEnergy.Location, model::Model)
```
