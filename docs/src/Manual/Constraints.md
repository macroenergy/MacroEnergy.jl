# Constraints

Macro constraints are attached to `Node`s, `Transformation`s, `Storage`s, and `Edge`s through each component's `constraints` field. Most users interact with them through JSON input files, while modelers encounter them when building assets and custom components.

## Constraint Library

The main user-facing list of available constraints is the [Macro Constraint Library](@ref macro_constraint_library).

## BalanceConstraint

[`BalanceConstraint`](@ref balance_constraint_ref) deserves special attention because it now supports more than equality-only flow balances.

A balance may:

- include `flow(...)` terms with algebraic coefficients
- use `==`, `<=`, or `>=`
- use scalar or time-varying coefficients

In practice, this means a modeler can define balances such as:

```julia
@add_balance(transform, :energy, flow(fuel_edge) == heat_rate * flow(elec_edge))
@add_balance(
    transform,
    :energy_lb,
    flow(fuel_edge) >= min_heat_rate * flow(elec_edge),
)
@add_stoichiometric_balance(
    transform,
    :conversion,
    fuel_rate * flow(fuel_edge) --> flow(elec_edge) + emission_rate * flow(co2_edge),
    flow(fuel_edge),
)
```

When `BalanceConstraint` is added to the host vertex, Macro compiles each named balance and applies the correct constraint sense at every time step.

## Asset Modeler Note

If you are creating or updating an asset `make` function, prefer:

- `@add_balance` for general balances
- `@add_stoichiometric_balance` for `-->` conversion shorthand

over writing raw `balance_data` dictionaries by hand.
