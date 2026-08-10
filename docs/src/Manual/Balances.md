# Balances

Balances in Macro define algebraic relationships between variables on a `Node`, `Transformation`, or `Storage`. They are used by [`BalanceConstraint`](@ref balance_constraint_ref) to build one constraint per balance ID and time step.

## Overview

At the user and modeler level, balances are usually defined with macros in asset `make` functions:

- `@add_balance` for general balances
- `@add_to_balance` for additive raw balance terms
- `@add_to_storage_balance` for storage law-of-motion terms
- `@add_stoichiometric_balance` for chemical-style `-->` shorthand

Under the hood, each balance is stored as a `BalanceData` object containing:

- a `sense` (`:eq`, `:le`, or `:ge`)
- a list of `BalanceTerm`s
- an optional constant term

Each `BalanceTerm` points to an object and variable, plus a coefficient.

## Choosing The Right Balance API

Use the balance macros according to the modeling task:

- Use `@add_balance(component, balance_id, equation)` for ordinary algebraic equalities or inequalities.
- Use `@add_to_balance(component, balance_id, expression)` when appending raw terms to an existing named balance.
- Use `@add_to_storage_balance(storage, expression)` when appending terms to a storage law of motion.
- Use `@add_stoichiometric_balance(component, balance_id, recipe, base_term)` when the conversion is easiest to express as a recipe and all coefficients share a common basis.

For most new asset code, `@add_balance` is the clearest default.

## Supported Balance Terms

The balance macros are flow-based. The supported variable term is:

- `flow(edge)`

Ordinary `+`, `-`, and constants are also allowed in balance expressions.

Use other constraints, rather than balances, for capacity, storage-level, commitment, or ramping logic.

## Coefficients

Macro supports three coefficient forms:

1. A single number, used at every time step.
2. A vector of length `1`, which is treated like a scalar.
3. A vector with one entry per time step of the host vertex, used as a time-varying coefficient profile.

Write coefficients before the flow term:

```julia
@add_balance(transform, :energy, heat_rate * flow(output_edge) == flow(input_edge))
```

For compound coefficients, group the coefficient expression before `flow(...)`,
for example `(heat_rate * availability_factor) * flow(edge)`.

`@add_balance` expects linear terms. Expressions such as `c / flow(edge)` are
nonlinear because they divide by a decision variable. Write every flow term as a
coefficient multiplied by a flow, such as `(1 / efficiency) * flow(edge)`.

## Equality And Inequality Balances

Balances may be written as equalities or inequalities.

```julia
@add_balance(transform, :energy, flow(fuel_edge) == heat_rate * flow(elec_edge))
@add_balance(
    transform,
    :energy_lb,
    flow(fuel_edge) >= min_heat_rate * flow(elec_edge),
)
```

These become `==`, `<=`, and `>=` `BalanceConstraint`s respectively.

Users should write these in ordinary algebraic form. MacroEnergy applies edge-direction handling under the hood so the compiled balance matches the equation as written, even when some flows are incoming and others are outgoing.

## Additive Balances

`@add_to_balance` is used when a balance already exists and the modeler wants to append extra terms:

```julia
@add_to_balance(transform, :emissions, emission_rate * flow(co2_edge))
```

This is most useful when the balance is naturally expressed as a sum of terms rather than as one explicit equation. The coefficients are stored as written, so for simple incoming/outgoing sums modelers typically use positive magnitudes and let edge direction supply the effective sign later in model construction.

For storage components, use `@add_to_storage_balance` instead:

```julia
@add_to_storage_balance(storage, 1 / discharge_efficiency * flow(discharge_edge))
@add_to_storage_balance(storage, charge_efficiency * flow(charge_edge))
```

This appends terms to the built-in `:storage` balance. In normal use, both inflow and outflow magnitudes are written as positive coefficients.

## Stoichiometric Shorthand

`@add_stoichiometric_balance` is a convenience macro for recipe-style or chemical-style relationships written with `-->`.

It expands a single stoichiometric expression into multiple pairwise balances, each anchored on the chosen `base_term`. In the example below, `flow(h2_edge)` is the base term, so Macro generates ordinary balances that each include `flow(h2_edge)`.

```julia
@add_stoichiometric_balance(
    electrolyzer,
    :energy,
    efficiency_rate * flow(elec_edge) + water_consumption * flow(water_edge) -->
    flow(h2_edge),
    flow(h2_edge),
)
```

Conceptually, this is useful when you want to express a conversion as a recipe and then have Macro break it into pairwise relationships. The example above expands into balances equivalent to:

```julia
@add_balance(
    electrolyzer,
    :energy_1,
    efficiency_rate * flow(elec_edge) - flow(h2_edge) == 0.0,
)
@add_balance(
    electrolyzer,
    :energy_2,
    water_consumption * flow(water_edge) - flow(h2_edge) == 0.0,
)
```

Notice that the generated balances are normalized around the chosen `base_term`. Here that means one balance relates hydrogen to electricity, and a second balance relates hydrogen to water.

More generally, each non-base term is related to the chosen `base_term` using the proportional rule:

```math
\text{base\_coeff} \cdot \phi_{term} - \text{term\_coeff} \cdot \phi_{base} = 0
```

where `base_coeff` is the coefficient on `base_term` in the stoichiometric expression.

The `-->` syntax is directional:

- left-hand terms are interpreted as incoming to the host component
- right-hand terms are interpreted as outgoing from the host component

Use this when the asset is easiest to describe as a stoichiometric conversion. For more general balances, `@add_balance` is the preferred interface.

### Coefficient Basis Requirement

All coefficients in one `@add_stoichiometric_balance` expression must share a common recipe basis.

This is the most important modeling rule for stoichiometric balances. For example:

- if the `base_term` is `flow(product_edge)` with coefficient `1`, other coefficients usually need to be written as “per unit product”
- if the `base_term` is `flow(fuel_edge)` with coefficient `1`, other coefficients usually need to be written as “per unit fuel”

If some inputs are naturally specified in different units, convert them before writing the stoichiometric balance.

For example, suppose:

- `fuel_per_alumina` is in `fuel / alumina`
- `emissions_per_fuel` is in `CO2 / fuel`

and the base term is `flow(alumina_edge)`. Then the CO2 term should be converted first:

```julia
emission_per_alumina = fuel_per_alumina * emissions_per_fuel
```

before it is used in `@add_stoichiometric_balance`.

### Pairwise Expansion Limitation

`@add_stoichiometric_balance` expands a recipe into pairwise balances between each non-base term and the chosen `base_term`.

That means it is well suited to proportional recipe relations, but it does **not** represent a general multi-term algebraic equation. In particular, it is not appropriate when the intended physics requires one balance with three or more independently varying terms on the same equation.

For example, a relation such as

```julia
A + B == C
```

cannot be represented faithfully by `@add_stoichiometric_balance`, because the macro will instead generate separate pairwise relations between `A` and `C`, and between `B` and `C`.

Assets such as `NaturalGasDAC`, where captured CO2 depends on the sum of more than one distinct contribution, should therefore use `@add_balance` rather than `@add_stoichiometric_balance`.

## Multi-Term Algebraic Balances

`@add_balance` does support three-term and larger algebraic equations:

```julia
@add_balance(transform, :capture, coeff_a * flow(a_edge) + coeff_b * flow(b_edge) == flow(c_edge))
```

However, modelers should use these balances carefully. A multi-term equation only constrains the total relationship shown in the equation. It does **not** by itself determine how the individual terms split unless additional balances, capacities, costs, or other constraints pin that split down.

For example:

```julia
A + B == C
```

allows many feasible decompositions of `C` unless there are other constraints on `A` and `B`. Depending on the surrounding model, the optimizer may choose `A = C, B = 0`, `A = 0, B = C`, or some other combination. This is often correct mathematically, but it may be surprising if the modeler intended a fixed ratio between `A` and `B`.

If a fixed ratio or recipe is intended, add the extra balances or constraints needed to define that ratio explicitly.

## Common Mistakes

Common balance-modeling mistakes include:

- mixing coefficient bases inside one `@add_stoichiometric_balance` expression
- using `@add_stoichiometric_balance` for a genuinely multi-term algebraic equation such as `A + B == C`
- assuming a balance like `A + B == C` also fixes the ratio between `A` and `B`
- writing manual sign flips for incoming and outgoing edges in `@add_balance`
- writing nonlinear terms such as `c / flow(edge)`; write variable terms as `coeff * flow(edge)`
- forgetting to add a small single-asset regression test when introducing or refactoring an asset balance

When a balance looks mathematically reasonable but produces surprising system results, these are the first issues to check.

## Legacy Balance Dictionaries

Legacy balance definitions of the form

```julia
Dict(:energy => Dict(edge_id => coeff))
```

are still normalized internally for backwards compatibility. New asset code should prefer the balance macros.

## Debugging Balances

When a balance is not behaving as expected, the most useful tools are:

- `@inspect_stoichiometric_balance(...)` to inspect the pairwise algebraic balances generated by `@add_stoichiometric_balance`
- `balance_data(component, balance_id)` to inspect the stored balance terms
- small single-asset tests in `test/asset_tests` to confirm the expected flows analytically

For quick inspection, the default form of `@inspect_stoichiometric_balance` skips edge-direction verification and simply shows the generated equations. If desired, pass `verify_edge_directions = true` to also validate that left-hand stoichiometric terms are incoming and right-hand terms are outgoing.

## Numerical Sensitivity

Large optimization models can be numerically sensitive to how an algebraically equivalent balance is written.

For example:

- `flow(output) == efficiency * flow(input)`
- `flow(input) == (1 / efficiency) * flow(output)`

describe the same feasible set, but they scale the constraint row differently. In a large model this can affect presolve, pivoting, dual values, and tie-breaking among near-equivalent technologies.

Small system-level result changes after a balance refactor do not necessarily imply a modeling error, especially when focused single-asset tests still pass and the new equations are algebraically equivalent.

## Node, Transformation, And Storage Balances

### Node Balances

Nodes commonly use balances to:

- enforce demand balance
- track policy-related balance expressions
- aggregate or split flows of a commodity

### Transformation Balances

Transformations use balances to describe conversion relationships such as:

- efficiencies
- mass balances
- emissions rates
- auxiliary consumption terms

### Storage Balances

Storage balances are used for:

- state-of-charge accounting
- charge/discharge efficiencies
- storage-specific additive terms built with `@add_to_storage_balance`
