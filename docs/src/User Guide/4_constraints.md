# Macro Constraint Library

Currently, Macro includes the following constraints:

## Balance constraint
```@docs
MacroEnergy.add_model_constraint!(ct::BalanceConstraint, v::MacroEnergy.AbstractVertex, model::Model)
```
## Capacity constraint
```@docs
MacroEnergy.add_model_constraint!(ct::CapacityConstraint, e::MacroEnergy.Edge, model::Model)
MacroEnergy.add_model_constraint!(ct::CapacityConstraint, e::MacroEnergy.EdgeWithUC, model::Model)
```
## CO2 capacity constraint
The CO2 capacity constraint is used to limit the amount of CO2 that can be emitted by a single CO2 node.
```@docs
MacroEnergy.add_model_constraint!(ct::CO2CapConstraint, n::Node{CO2}, model::Model)
```

## Long-duration storage constraints
These additional constraints (and variables) can be used to ensure that storage levels of long-duration storage systems do not exceed installed capacity over non-representative subperiods. 

For a complete description of the constraints, see the paper: "Improved formulation for long-duration storage in capacity expansion models using representative periods", Federico Parolin, Paolo Colbertaldo, Ruaridh Macdonald, 2024, [https://doi.org/10.48550/arXiv.2409.19079](https://doi.org/10.48550/arXiv.2409.19079).

```@docs
MacroEnergy.add_model_constraint!(ct::LongDurationStorageImplicitMinMaxConstraint, g::LongDurationStorage, model::Model)
```

## Maximum capacity constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MaxCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)
```
## Maximum non-served demand constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MaxNonServedDemandConstraint, n::Node, model::Model)
```
## Maximum non-served demand per segment constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MaxNonServedDemandPerSegmentConstraint, n::Node, model::Model)
```
## Maximum storage level constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MaxStorageLevelConstraint, g::AbstractStorage, model::Model)
```
## Minimum capacity constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MinCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)
```
## Minimum flow constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MinFlowConstraint, e::Edge, model::Model)
MacroEnergy.add_model_constraint!(ct::MinFlowConstraint, e::EdgeWithUC, model::Model)
```
## Minimum storage level constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MinStorageLevelConstraint, g::AbstractStorage, model::Model)
```
## Minimum storage outflow constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MinStorageOutflowConstraint, g::AbstractStorage, model::Model)
```

## Minimum up and down time constraint

```@docs
MacroEnergy.add_model_constraint!(ct::MinUpTimeConstraint, e::EdgeWithUC, model::Model)
MacroEnergy.add_model_constraint!(ct::MinDownTimeConstraint, e::EdgeWithUC, model::Model)
```

## Must-run constraint
```@docs
MacroEnergy.add_model_constraint!(ct::MustRunConstraint, e::Edge, model::Model)
```
## Ramping limits constraint
```@docs
MacroEnergy.add_model_constraint!(ct::RampingLimitConstraint, e::Edge, model::Model)
MacroEnergy.add_model_constraint!(ct::RampingLimitConstraint, e::EdgeWithUC, model::Model)
```
## Storage capacity constraint
```@docs
MacroEnergy.add_model_constraint!(ct::StorageCapacityConstraint, g::AbstractStorage, model::Model)
```
## Storage discharge limit constraint
```@docs
MacroEnergy.add_model_constraint!(ct::StorageDischargeLimitConstraint, e::Edge, model::Model)
```
## Storage symmetric capacity constraint
```@docs
MacroEnergy.add_model_constraint!(ct::StorageSymmetricCapacityConstraint, g::AbstractStorage, model::Model)
```
## Storage charge discharge ratio constraint
```@docs
MacroEnergy.add_model_constraint!(
        ct::StorageChargeDischargeRatioConstraint,
        g::AbstractStorage,
        model::Model,
)
```
## Storage max duration constraint
```@docs
MacroEnergy.add_model_constraint!(ct::StorageMaxDurationConstraint, g::AbstractStorage, model::Model)
```
## Storage min duration constraint
```@docs
MacroEnergy.add_model_constraint!(ct::StorageMinDurationConstraint, g::AbstractStorage, model::Model)
```
