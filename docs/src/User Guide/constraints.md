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
## CO2 capture constraint

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
