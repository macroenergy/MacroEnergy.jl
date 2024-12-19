# Macro Constraint Library

Currently, Macro includes the following constraints:

- **Balance constraint**
```@docs
Macro.add_model_constraint!(ct::BalanceConstraint, v::Macro.AbstractVertex, model::Macro.Model)
```
- **Capacity constraint**
```@docs
Macro.add_model_constraint!(ct::CapacityConstraint, e::Macro.Edge, model::Macro.Model)
Macro.add_model_constraint!(ct::CapacityConstraint, e::Macro.EdgeWithUC, model::Macro.Model)
```
- **CO2 capture constraint**

- **Maximum capacity constraint**
```@docs
Macro.add_model_constraint!(ct::MaxCapacityConstraint, e::Edge, model::Macro.Model)
Macro.add_model_constraint!(ct::MaxCapacityConstraint, s::Storage, model::Macro.Model)
```
- **Maximum non-served demand constraint**
```@docs
Macro.add_model_constraint!(ct::MaxNonServedDemandConstraint, n::Node, model::Macro.Model)
```
- **Maximum non-served demand per segment constraint**
```@docs
Macro.add_model_constraint!(ct::MaxNonServedDemandPerSegmentConstraint, n::Node, model::Macro.Model)
```
- **Maximum storage level constraint**
```@docs
Macro.add_model_constraint!(ct::MaxStorageLevelConstraint, s::Storage, model::Macro.Model)
```
- **Minimum capacity constraint**
```@docs
Macro.add_model_constraint!(ct::MinCapacityConstraint, e::Edge, model::Macro.Model)
Macro.add_model_constraint!(ct::MinCapacityConstraint, s::Storage, model::Macro.Model)
```
- **Minimum flow constraint**
```@docs
Macro.add_model_constraint!(ct::MinFlowConstraint, e::Edge, model::Macro.Model)
Macro.add_model_constraint!(ct::MinFlowConstraint, e::EdgeWithUC, model::Macro.Model)
```
- **Minimum storage level constraint**
```@docs
Macro.add_model_constraint!(ct::MinStorageLevelConstraint, s::Storage, model::Macro.Model)
```
- **Minimum storage outflow constraint**
```@docs
Macro.add_model_constraint!(ct::MinStorageOutflowConstraint, s::Storage, model::Macro.Model)
```
- **Minimum up and down time constraint**
```@docs
Macro.add_model_constraint!(ct::MinUpTimeConstraint, e::EdgeWithUC, model::Macro.Model)
Macro.add_model_constraint!(ct::MinDownTimeConstraint, e::EdgeWithUC, model::Macro.Model)
```
- **Must-run constraint**
```@docs
Macro.add_model_constraint!(ct::MustRunConstraint, e::Edge, model::Macro.Model)
```
- **Ramping limits constraint**
```@docs
Macro.add_model_constraint!(ct::RampingLimitConstraint, e::Edge, model::Macro.Model)
Macro.add_model_constraint!(ct::RampingLimitConstraint, e::EdgeWithUC, model::Macro.Model)
```
- **Storage capacity constraint**
```@docs
Macro.add_model_constraint!(ct::StorageCapacityConstraint, s::Storage, model::Macro.Model)
```
- **Storage discharge limit constraint**
```@docs
Macro.add_model_constraint!(ct::StorageDischargeLimitConstraint, e::Edge, model::Macro.Model)
```
- **Storage symmetric capacity constraint**
```@docs
Macro.add_model_constraint!(ct::StorageSymmetricCapacityConstraint, s::Storage, model::Macro.Model)
```
- **Storage charge discharge ratio constraint**
```@docs
Macro.add_model_constraint!(
        ct::StorageChargeDischargeRatioConstraint,
        s::Storage,
        model::Macro.Model,
)
```
- **Storage max duration constraint**
```@docs
Macro.add_model_constraint!(ct::StorageMaxDurationConstraint, s::Storage, model::Macro.Model)
```
- **Storage min duration constraint**
```@docs
Macro.add_model_constraint!(ct::StorageMinDurationConstraint, s::Storage, model::Macro.Model)
```
