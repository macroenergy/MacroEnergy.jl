# Adding Asset Constraints to a System

One of Macro's most powerful features is the ability to enable and disable constraints through input switches without modifying the source code. 

This guide documents all available constraints and explains how to enable them in your system.

!!! tip "Important - Attribute Prefixes"
    The **prefix** before `_constraints` (and all other attributes) in the JSON input file varies depending on the component of the asset that the constraint is applied to. Some examples are:
    - `transform_constraints`: constraints on the conversion component of an asset
    - `storage_constraints`: constraints on the storage component of an asset
    - `elec_constraints`: constraints on the power input/output component of an asset
    - `discharge_constraints`: constraints on the discharging component of an asset
    - etc.

    Throughout this guide, we show examples with different prefixes to illustrate this variety. When implementing constraints for your specific asset, make sure to review [this example case](https://github.com/macroenergy/MacroEnergyExamples.jl/tree/main/examples/multisector_three_zones_reduced/assets) or the asset definition in the [Macro Asset Library](@ref) to make sure you use the correct prefix for your asset type.

## Balance Constraint

*Note: Enabled by default in all assets in the [Macro Asset Library](@ref)*

The balance constraint ensures that the sum of inflows and outflows at any component of an asset equals zero at each time step.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \sum_{i \in \text{inflows}} \text{flow(i, t)} - \sum_{o \in \text{outflows}} \text{flow(o, t)} = 0
    \end{aligned}
    ```

While enabled by default in all assets in the [Macro Asset Library](@ref), the user can explicitly enable or disable it by adding these lines to their asset's JSON input file:

```json
{
    "transform_constraints": {
        "BalanceConstraint": true/false
    },
    "storage_constraints": {
        "BalanceConstraint": true/false
    }
}
```

## Capacity Constraint
*Note: Enabled by default in all assets in the [Macro Asset Library](@ref)*

The capacity constraint ensures that the **flow** of a commodity through an edge of an asset (e.g, power output) does not exceed the nameplate capacity (multiplied by its availability factor).


!!! note "Formulation - Assets without unit commitment"
    For unidirectional edges, the constraint takes this form:
    ```math
    \begin{aligned}
        \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)}
    \end{aligned}
    ```

    For bidirectional edges:
    ```math
    \begin{aligned}
        \text{sign(e)} \times \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)}
    \end{aligned}
    ```

    where `sign(e)` is the sign of the flow of the edge, which is `1` for positive flows and `-1` for negative flows.


!!! note "Formulation - Assets with unit commitment"
    Unidirectional edges:
    ```math
    \begin{aligned}
        \sum_{t \in \text{time\_interval(e)}} \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)} \times \text{ucommit(e, t)}
    \end{aligned}
    ```

    Bidirectional edges:
    ```math
    \begin{aligned}
        \text{sign(e)} \times \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)} \times \text{ucommit(e, t)}
    \end{aligned}
    ```

    where `sign(e)` is the sign of the flow of the edge, which is `1` for positive flows and `-1` for negative flows.

The capacity constraint is enabled by default in all assets in the [Macro Asset Library](@ref). The user can enable/disable it by adding these lines to their asset's JSON input file:

```json
{
    "elec_constraints": {
        "CapacityConstraint": true/false
    }
}
```

As a reminder, users can define the availability as a time series in the asset's JSON input file using the following format:

- **Vector of numbers**
```json
{
    "availability": [0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9]
}
```

- **Column in a CSV file**
```json
{
    "availability": {
        "timeseries": {
            "path": "system/availability.csv",
            "header": "<asset_id>"
        }
    }
}
```

## Maximum Capacity
The maximum capacity constraint enforces that the **capacity** of an edge or storage of an asset does not exceed the `max_capacity` attribute as specified in the JSON input file.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{capacity(y)} \leq \text{max\_capacity(y)}
    \end{aligned}
    ```

    where `y` is the edge or storage of the asset.

To enable this constraint:

1. Add the `MaxCapacityConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `max_capacity` attribute of the asset.

```json
{
    "elec_constraints": {
        "MaxCapacityConstraint": true
    },
    "max_capacity": 27760
}
```

## Minimum Capacity
The minimum capacity constraint enforces that the **capacity** of an edge or storage of an asset is greater than or equal to the `min_capacity` attribute as specified in the JSON input file.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{capacity(y)} \geq \text{min\_capacity(y)}
    \end{aligned}
    ```

    where `y` is the edge or storage of the asset.

To enable this constraint:

1. Add the `MinCapacityConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `min_capacity` attribute of the asset.

```json
{
    "elec_constraints": {
        "MinCapacityConstraint": true
    },
    "min_capacity": 100
}
```

## Minimum Flow Constraint
The minimum flow constraint enforces that the **flow** of a commodity in an edge does not exceed a user-defined fraction of the capacity of the edge (specified using the `min_flow_fraction` attribute).

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{flow(e, t)} \geq \text{min\_flow\_fraction(e)} \times \text{capacity(e)}
    \end{aligned}
    ```
    where `e` is the edge of the asset.

    In the case of edges with unit commitment, the constraint becomes:
    ```math
    \begin{aligned}
        \text{flow(e, t)} \geq \text{min\_flow\_fraction(e)} \times \text{capacity\_size(e)} \times \text{ucommit(e, t)}
    \end{aligned}
    ```
    where `e` is the edge of the asset, and where `capacity_size(e)*ucommit(e, t)` is the total capacity of the edge that is available at time `t`.


To enable this constraint:

1. Add the `MinFlowConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `min_flow_fraction` attribute of the asset.

```json
{
    "elec_constraints": {
        "MinFlowConstraint": true
    },
    "min_flow_fraction": 0.5
}
```

!!! warning "Unidirectional Edges Only"
    This constraint is available only for unidirectional edges.

## Minimum Up/Down Time (Unit Commitment)
The minimum up/down time constraint enforces that edges with unit commitment must be on/off for a minimum number of time steps (specified using the `min_up_time`/`min_down_time` attribute).

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{ucommit(e, t)} \geq \sum_{h=0}^{\text{min\_up\_time(e)}-1} \text{ustart(e, t-h)}
    \end{aligned}
    ```
    ```math
    \begin{aligned}
        \frac{\text{capacity(e)}}{\text{capacity\_size(e)}} - \text{ucommit(e, t)} \geq \sum_{h=0}^{\text{min\_down\_time(e)}-1} \text{ushut(e, t-h)}
    \end{aligned}
    ```

    where `e` is the edge of the asset. 

To enable this constraint:

1. Add the `MinUpTimeConstraint`/`MinDownTimeConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `min_up_time`/`min_down_time` attribute of the asset.

```json
{
    "elec_constraints": {
        "MinUpTimeConstraint": true,
        "MinDownTimeConstraint": true
    },
    "min_up_time": 6,
    "min_down_time": 6
}
```

!!! warning "Min up/down time duration - subperiods"
    This constraint will throw an error if the minimum up/down time is longer than the length of one subperiod.

## Must Run Constraint
The must run constraint forces an edge to operate at its full capacity (adjusted by availability) at all times.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{flow(e, t)} = \text{availability(e, t)} \times \text{capacity(e)}
    \end{aligned}
    ```

    where `e` is the edge of the asset.

To enable this constraint:

1. Add the `MustRunConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. (optional) Add a time series with the availability of the edge.

```json
{
    "elec_constraints": {
        "MustRunConstraint": true
    },
    "availability": {
        "timeseries": {
            "path": "system/availability.csv",
            "header": "<asset_id>"
        }
    }
}
```

!!! warning "Must run constraint"
    This constraint is available only for unidirectional edges.

## Ramping Limit Constraint (RampUp/RampDown)
The ramping limits constraint restricts how quickly the **flow** through an edge can change between consecutive time steps. The maximum rate of change is defined as a fraction of the edge's capacity (`ramp_up_fraction`/`ramp_down_fraction`).

!!! note "Formulation - Assets without unit commitment"
    ```math
    \begin{aligned}
        \text{flow(e, t)} - \text{flow(e, t-1)} \leq \text{ramp\_up\_fraction(e)} \times \text{capacity(e)}
    \end{aligned}
    ```
    ```math
    \begin{aligned}
        \text{flow(e, t-1)} - \text{flow(e, t)} \leq \text{ramp\_down\_fraction(e)} \times \text{capacity(e)}
    \end{aligned}
    ```

!!! note "Formulation - Assets with unit commitment"
    ```math
    \begin{aligned}
        \text{flow(e, t)} - \text{flow(e, t-1)} - \text{ramp\_up\_fraction(e)} \times \text{capacity\_size(e)} \times (\text{ucommit(e, t)} - \text{ustart(e, t)}) + \text{min(availability(e, t), max(min\_flow\_fraction(e), ramp\_up\_fraction(e)))} \times \text{capacity\_size(e)} \times \text{ustart(e, t)} - \text{min\_flow\_fraction(e)} \times \text{capacity\_size(e)} \times \text{ushut(e, t)} \leq 0
    \end{aligned}
    ```
    ```math
    \begin{aligned}
        \text{flow(e, t-1)} - \text{flow(e, t)} - \text{ramp\_down\_fraction(e)} \times \text{capacity\_size(e)} \times (\text{ucommit(e, t)} - \text{ustart(e, t)}) - \text{min\_flow\_fraction(e)} \times \text{capacity\_size(e)} \times \text{ustart(e, t)} + \text{min(availability(e, t), max(min\_flow\_fraction(e), ramp\_down\_fraction(e)))} \times \text{capacity\_size(e)} \times \text{ushut(e, t)} \leq 0
    \end{aligned}
    ```

To enable this constraint:

1. Add the `RampingLimitConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `ramp_up_fraction`/`ramp_down_fraction` attribute of the asset.

```json
{
    "elec_constraints": {
        "RampingLimitConstraint": true
    },
    "ramp_up_fraction": 0.6,
    "ramp_down_fraction": 0.6
}
```

## Storage Capacity Constraint
*Note: Enabled by default for batteries and gas storage assets*

This constraint ensures that the **storage level** of a storage component of an asset never exceeds its total energy capacity.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{storage\_level(g, t)} \leq \text{capacity(g)}
    \end{aligned}
    ```

    where `g` is the storage of the asset.

As mentioned above, this constraint is enabled by default for batteries and gas storage assets. To enable/disable this constraint for other assets, use the following:

1. Add the `StorageCapacityConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.

```json
{
    "storage_constraints": {
        "StorageCapacityConstraint": true
    }
}
```

## Maximum Storage Level
The maximum storage level constraint enforces that the **storage level** of a storage component of an asset does not exceed the `capacity` times the `max_storage_level` attribute as specified in the JSON input file.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{storage\_level(g, t)} \leq \text{max\_storage\_level(g)} \times \text{capacity(g)}
    \end{aligned}
    ```

    where `g` is the storage of the asset.

To enable this constraint:

1. Add the `MaxStorageLevelConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `max_storage_level` attribute of the asset.

```json
{
    "storage_constraints": {
        "MaxStorageLevelConstraint": true
    },
    "max_storage_level": 1
}
```

## Minimum Storage Level
The minimum storage level constraint enforces that the **storage level** of a storage component of an asset does not exceed the `capacity` times the `min_storage_level` attribute as specified in the JSON input file.   

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{storage\_level(g, t)} \geq \text{min\_storage\_level(g)} \times \text{capacity(g)}
    \end{aligned}
    ```

    where `g` is the storage of the asset.

To enable this constraint:

1. Add the `MinStorageLevelConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `min_storage_level` attribute of the asset.

```json
{
    "storage_constraints": {
        "MinStorageLevelConstraint": true
    },
    "min_storage_level": 0.3
}
```

## Storage Charge/Discharge Ratio

The storage charge/discharge ratio constraint links the capacity of the charging edge to the capacity of the discharging edge through the `charge_discharge_ratio` input parameter.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{charge\_discharge\_ratio} \times \text{capacity(discharge\_edge)} = \text{capacity(charge\_edge)}
    \end{aligned}
    ```

To enable this constraint:

1. Add the `StorageChargeDischargeRatioConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `charge_discharge_ratio` attribute of the asset.

```json
{
    "storage_constraints": {
        "StorageChargeDischargeRatioConstraint": true
    },
    "storage_charge_discharge_ratio": 0.5
}
```

!!! warning "Constraint Application Scope"
    As noted above, this constraint is applied to the storage component of the asset, not to the individual charging and discharging edges.

## Storage Discharge Limit Constraint
*Note: Enabled by default for batteries.*

The storage discharge limit constraint ensures that the flow through a discharging edge (adjusted for efficiency) cannot exceed the storage level from the previous time step.

!!! note "Formulation"
    ```math
    \begin{aligned}
       \frac{\text{flow(discharge\_edge, t)}}{\text{efficiency(discharge\_edge)}} \leq \text{storage\_level(t-1)}
    \end{aligned}
    ```

To enable this constraint:

1. Add the `StorageDischargeLimitConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.

```json
{
    "discharge_constraints": {
        "StorageDischargeLimitConstraint": true
    }
}
```

!!! warning "Constraint Application Scope"
    This constraint is applied to discharging edges only.

## Storage Charge Limit Constraint
*Note: Enabled by default for batteries.*

The storage charge limit constraint ensures that the flow through a charging edge (adjusted for efficiency) cannot exceed the available storage capacity at the previous time step.

!!! note "Formulation"
    ```math
   \begin{aligned}
      \text{efficiency(e)}\text{flow(e, t)} \leq \text{capacity(end\_vertex(e))} - \text{storage\_level(end\_vertex(e), timestepbefore(t, 1, subperiods(e)))}
   \end{aligned}
    ```

To enable this constraint:

1. Add the `StorageChargeLimitConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.

```json
{
    "charge_constraints": {
        "StorageChargeLimitConstraint": true
    }
}
```

!!! warning "Constraint Application Scope"
    This constraint is applied to charging edges only.

## Storage Maximum/Minimum Duration Constraint
This constraint limits the maximum/minimum energy capacity that can be stored relative to the discharging capacity. The limit is specified in the `max_duration`/`min_duration` attribute as a number of time steps.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{capacity(storage)} \leq \text{max\_duration} \times \text{capacity(discharge\_edge)}
    \end{aligned}
    ```
    ```math
    \begin{aligned}
        \text{capacity(storage)} \geq \text{min\_duration} \times \text{capacity(discharge\_edge)}
    \end{aligned}
    ```

To enable this constraint:

1. Add the `StorageMaxDurationConstraint`/`StorageMinDurationConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `storage_max_duration`/`storage_min_duration` attribute of the asset.

```json
{
    "storage_constraints": {
        "StorageMaximumDurationConstraint": true
    },
    "storage_max_duration": 10,
    "storage_min_duration": 1
}
```

## Storage Symmetric Capacity Constraint
This constraint ensures that for symmetric storage systems, the maximum simultaneous charge and discharge cannot exceed the capacity of the discharging edge.

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{flow(e\_discharge, t)} + \text{flow(e\_charge, t)} \leq \text{capacity(e\_discharge)}
    \end{aligned}
    ```

To enable this constraint:

1. Add the `StorageSymmetricCapacityConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.

```json
{
    "discharge_constraints": {
        "StorageSymmetricCapacityConstraint": true
    }
}
```

!!! warning "Constraint Application Scope"
    This constraint is applied to the discharging edge of the asset.

## Minimum Storage Outflow

!!! warning "HydroRes Assets Only"
    This constraint is specifically designed for `HydroRes` assets. A warning will be issued otherwise.

    **Tip**: If the discharge edge is the only outflow, use the `MinFlowConstraint` on the discharge edge instead.

The minimum storage outflow constraint enforces that the sum of the flow through the spillage edge and the discharge edge does not exceed a user-defined fraction of the capacity of the discharge edge (`min_outflow_fraction` attribute).

!!! note "Formulation"
    ```math
    \begin{aligned}
        \text{flow(spillage\_edge, t)} + \text{flow(discharge\_edge, t)} \geq \text{min\_outflow\_fraction} \times \text{capacity(discharge\_edge)}
    \end{aligned}
    ```

To enable this constraint:

1. Add the `MinStorageOutflowConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.
2. Add a value to the `min_outflow_fraction` attribute of the asset.

```json
{
    "storage_constraints": {
        "MinStorageOutflowConstraint": true
    },
    "min_outflow_fraction": 0.1
}
```

## Long Duration Storage Implicit Min/Max Constraint
*Note: Enabled by default for batteries, gas storage, and hydro reservoirs when `long_duration` is set to `true` in the asset JSON input file.*

This set of constraints manages storage levels for **long duration storage systems** when modeling representative periods. The implementation is based on the paper: "Improved formulation for long-duration storage in capacity expansion models using representative periods" by Federico Parolin, Paolo Colbertaldo, and Ruaridh Macdonald, 2024 ([arXiv:2409.19079](https://doi.org/10.48550/arXiv.2409.19079)). For detailed information about the constraint formulation, please refer to the paper.

This constraint is enabled by default for batteries, gas storage, and hydro reservoirs when `long_duration` is set to `true` in the asset JSON input file. To enable/disable this constraint for other assets, use the following:
1. Add the `LongDurationStorageImplicitMinMaxConstraint` to the list of constraints in the JSON input file of the asset and set it to `true`.

```json
{
    "storage_long_duration": true,
    "storage_constraints": {
        "LongDurationStorageImplicitMinMaxConstraint": true/false
    }
}
```
