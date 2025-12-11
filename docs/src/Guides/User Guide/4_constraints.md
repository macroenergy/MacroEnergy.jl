# [Macro Constraint Library](@id macro_constraint_library)

Currently, Macro includes the following constraints:

## [Balance constraint](@id balance_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::BalanceConstraint, v::MacroEnergy.AbstractVertex, model::Model)
```
## [Capacity constraint](@id capacity_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::CapacityConstraint, e::MacroEnergy.Edge, model::Model)
MacroEnergy.add_model_constraint!(ct::CapacityConstraint, e::MacroEnergy.EdgeWithUC, model::Model)
```
## [CO2 capacity constraint](@id co2_capacity_constraint_ref)
The CO2 capacity constraint is used to limit the amount of CO2 that can be emitted by a single CO2 node.
```@docs
MacroEnergy.add_model_constraint!(ct::CO2CapConstraint, n::Node{CO2}, model::Model)
```
## [Aggregated demand constraint](@id aggregated_demand_constraint_ref)
The aggregated demand constraint sets the level of demand that must be met at a node over the entire optimization period.
```@docs
MacroEnergy.add_model_constraint!(ct::AggregatedDemandConstraint, n::Node{T}, model::Model) where {T}
```
## [Long-duration storage constraints](@id long_duration_storage_constraints_ref)
These additional constraints (and variables) can be used to ensure that storage levels of long-duration storage systems do not exceed installed capacity over non-representative subperiods. 

For a complete description of the constraints, see the paper: "Improved formulation for long-duration storage in capacity expansion models using representative periods", Federico Parolin, Paolo Colbertaldo, Ruaridh Macdonald, 2024, [https://doi.org/10.48550/arXiv.2409.19079](https://doi.org/10.48550/arXiv.2409.19079).

```@docs
MacroEnergy.add_model_constraint!(ct::LongDurationStorageImplicitMinMaxConstraint, g::LongDurationStorage, model::Model)
```

## [Maximum capacity constraint](@id max_capacity_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MaxCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)
```
## [Maximum non-served demand constraint](@id max_non_served_demand_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MaxNonServedDemandConstraint, n::Node, model::Model)
```
## [Maximum non-served demand per segment constraint](@id max_non_served_demand_per_segment_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MaxNonServedDemandPerSegmentConstraint, n::Node, model::Model)
```
## [Maximum storage level constraint](@id max_storage_level_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MaxStorageLevelConstraint, g::AbstractStorage, model::Model)
```
## [Minimum capacity constraint](@id min_capacity_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MinCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)
```
## [Minimum flow constraint](@id min_flow_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MinFlowConstraint, e::Edge, model::Model)
MacroEnergy.add_model_constraint!(ct::MinFlowConstraint, e::EdgeWithUC, model::Model)
```
## [Minimum storage level constraint](@id min_storage_level_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MinStorageLevelConstraint, g::AbstractStorage, model::Model)
```
## [Minimum storage outflow constraint](@id min_storage_outflow_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MinStorageOutflowConstraint, g::AbstractStorage, model::Model)
```

## [Minimum up and down time constraint](@id min_up_and_down_time_constraint_ref)

```@docs
MacroEnergy.add_model_constraint!(ct::MinUpTimeConstraint, e::EdgeWithUC, model::Model)
MacroEnergy.add_model_constraint!(ct::MinDownTimeConstraint, e::EdgeWithUC, model::Model)
```

## [Must-run constraint](@id must_run_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::MustRunConstraint, e::Edge, model::Model)
```
## [Ramping limits constraint](@id ramping_limits_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::RampingLimitConstraint, e::Edge, model::Model)
MacroEnergy.add_model_constraint!(ct::RampingLimitConstraint, e::EdgeWithUC, model::Model)
```
## [Storage capacity constraint](@id storage_capacity_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::StorageCapacityConstraint, g::AbstractStorage, model::Model)
```
## [Storage discharge limit constraint](@id storage_discharge_limit_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::StorageDischargeLimitConstraint, e::Edge, model::Model)
```
## [Storage symmetric capacity constraint](@id storage_symmetric_capacity_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::StorageSymmetricCapacityConstraint, g::AbstractStorage, model::Model)
```
## [Storage charge discharge ratio constraint](@id storage_charge_discharge_ratio_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(
        ct::StorageChargeDischargeRatioConstraint,
        g::AbstractStorage,
        model::Model,
)
```
## [Storage max duration constraint](@id storage_max_duration_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::StorageMaxDurationConstraint, g::AbstractStorage, model::Model)
```
## [Storage min duration constraint](@id storage_min_duration_constraint_ref)
```@docs
MacroEnergy.add_model_constraint!(ct::StorageMinDurationConstraint, g::AbstractStorage, model::Model)
```
## [Retrofitting constraint](@id retrofitting_constraint_ref)
```@docs
MacroEnergy.add_retrofit_constraints!(system::MacroEnergy.System, period_idx::Int, model::Model)
```