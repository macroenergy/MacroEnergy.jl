# [Flow Credits](@id user_flow_credit)

## Contents

[Overview](@ref flow_credit_overview) | [Configure a Credit](@ref flow_credit_input) | [Accounting](@ref flow_credit_accounting) | [Benders Settings](@ref flow_credit_benders) | [Multiple Periods](@ref flow_credit_periods) | [Outputs](@ref flow_credit_outputs)

## [Overview](@id flow_credit_overview)

A flow credit reduces operating cost in proportion to the actual flow on a selected edge. Production tax credits (PTCs) are one application. Users choose the purpose and eligible activity. Macro records the payment separately from variable operation and maintenance cost (VOM).

Enter a positive `flow_credit_rate` when a credit applies, or zero when it does not. The model calculates a nonnegative payment and subtracts it once from operating cost. Keep `variable_om_cost` at its value before the credit.

!!! warning "Avoid counting the credit twice"
    If an input previously included a credit as a reduction in VOM, restore the VOM before setting `flow_credit_rate`. A negative `flow_credit_rate` is not accepted.

## [Configure a Credit](@id flow_credit_input)

`flow_credit_rate` is a finite, nonnegative scalar in monetary units per unit of the selected commodity. Its default is `0.0`. Supply one value per edge and investment period. Strings, Boolean values, arrays, negative numbers, and non-finite values are rejected.

For a VRE asset, add the rate to `edges.edge`:

```json
{
    "edges": {
        "edge": {
            "variable_om_cost": 3.0,
            "flow_credit_rate": 40.0
        }
    }
}
```

This is an asset input fragment. For ThermalPower, the usual edge is `elec_edge`; for Electrolyzer, it is `h2_edge`. Both electricity and hydrogen use MWh in Macro's default convention. A policy rate in currency per kilogram of hydrogen must first be converted to the model's unit.

A positive rate requires a unidirectional edge whose asset definition sets `has_capacity=true` in its full defaults. Macro checks these defaults before considering user overrides. There is no asset-type or commodity whitelist.

| Edge configuration | Positive credit |
|---|---|
| The asset default has `has_capacity=true` | Allowed on a unidirectional edge |
| The user disables capacity on that default capacity edge | Still allowed; other model requirements still apply |
| The user disables `CapacityConstraint` | Still allowed on that default capacity edge |
| The asset default has `has_capacity=false`, but the user enables capacity | Rejected |
| The edge is bidirectional | Rejected; zero credit preserves the existing behavior |

`has_capacity` controls capacity variables. `CapacityConstraint` controls the link between flow and capacity. Unit commitment still requires capacity, independently of credit eligibility.

The selected edge can represent an input or an output. For example, BECCSHydrogen uses its biomass input as the default capacity edge. A credit on that edge is in currency per tonne of biomass, not per MWh of hydrogen. Users must convert output-based policy rates when the conversion relationship permits it. Macro does not infer the policy basis.

The same interface permits credits on default capacity edges of single-direction transmission and storage assets. Users determine whether these activities should receive a credit.

### Credits on storage and cyclic flows

Credits apply to the flow on each selected edge, not to net production or final delivery. Crediting both charging and discharging can therefore reward repeated storage cycles. Similar incentives can occur across connected transport or conversion assets.

If cycle payments exceed operating and capacity costs, the model can increase cyclic flows to collect credits. Select credited edges and rates carefully. Check whether the policy intends to reward each activity separately, especially when several edges carry the same commodity through a chain.

Default capacity-edge eligibility does not prevent this behavior.

### Input forms

Set `flow_credit_rate` inside `edges.<edge_name>` to identify the credited edge explicitly. For example, a Battery discharge credit uses:

```json
{
    "edges": {
        "discharge_edge": {
            "flow_credit_rate": 40.0
        }
    }
}
```

Asset-level shorthand follows each asset's existing VOM input mapping. Use a supported edge prefix, such as `discharge_flow_credit_rate` for Battery or `biomass_flow_credit_rate` for BECCSHydrogen. Edge-specific values take precedence over the corresponding asset-level shorthand. Instance data still take precedence over global data at the same input path.

An unprefixed asset-level `flow_credit_rate` is not a common interface for all assets. Battery ignores it. BECCSHydrogen passes it to multiple edges, which can cause an eligibility error on an auxiliary edge. Use the explicit edge form when the asset's shorthand mapping is uncertain.

Payment outputs use `flow_credits.csv` by default and the negative `FlowCredit` cost category. The payment file follows `WriteOutputs.Costs` and `OutputFormat.Costs`, including a global `OutputFormat` value. Disabling cost outputs also disables the payment file. Cost and payment outputs retain full numerical precision.

### Custom assets

A custom asset can use the same mechanism without registration in a credit-specific list. Its `default_data(AssetType, id, "full")` must identify the eligible edge under `:edges` with `:has_capacity => true`. The edge key must match the corresponding asset field, as in the standard asset interface. Constructors must pass `flow_credit_rate` to the edge.

The standard asset and edge modeling methods apply the eligibility check and the payment. Custom implementations that replace these methods must preserve the checks and cost calls. Commodity names are preserved in output; missing unit declarations are not guessed.

## [Accounting](@id flow_credit_accounting)

Let ``r_{e,p}`` be the rate for edge ``e`` in investment period ``p``, ``q_{e,t}`` its nonnegative edge flow, and ``\omega_{w(t)}`` the representative-subperiod weight. The annual weighted payment is:

```math
P_p = \sum_e \sum_t \omega_{w(t)} r_{e,p} q_{e,t}.
```

Macro follows the existing VOM flow and time-weight convention. The native input workflow uses 1 h steps, so hourly flow and the corresponding commodity quantity have the same numerical value for each step. Payments use actual edge flow. Unused capacity and curtailed availability receive no payment.

The annual net operating cost is:

```math
C^{\mathrm{net}}_{\mathrm{op},p} = C^{\mathrm{original}}_{\mathrm{op},p} - P_p.
```

The credit is included in net operating cost before the existing financial path applies the period discount factor and present-value annuity factor. The credit does not add decision variables or constraints. It works with positive, zero, or negative VOM and with both UC and non-UC edges. Fuel and startup costs retain their existing calculations.

Payment reports calculate the credit separately from solved flows, time weights, and the supplied rates. This separate reporting does not add the payment to the objective again.

Parameter scaling divides both the rate and edge flow by ``S``, so model payments are divided by ``S^2``. Native output restores the original units once. Do not rescale those output values again.

The term *annual* follows the supplied time weights. A case containing 168 h with unit weights represents those 168 h; Macro does not automatically multiply it to 8,760 h. See [Financial Assumptions](../../Manual/Financial_assumptions.md) and [Costs Output](@ref manual-outputs-costs) for the existing cost conventions.

## [Benders Settings](@id flow_credit_benders)

A flow credit can make net operating cost negative. A zero operating-cost lower bound is therefore not assumed to be valid for Benders models with positive flow credits.

Set `BendersSettings.OperatingCostLowerBounds` as a mapping from investment-period indices to arrays. Each array follows that period's subproblem order. Each entry is an annual operating-cost lower bound in **original monetary units, already including the representative-subperiod weight**. Do not include period length, discounting, or parameter scaling.

For a one-period model with one subproblem:

```json
{
    "SolutionAlgorithm": "Benders",
    "BendersSettings": {
        "OperatingCostLowerBounds": {
            "1": [-4000.0]
        },
        "IncludeSubproblemSlacksAutomatically": false,
        "ExpectFeasibleSubproblems": true
    }
}
```

The bound above is valid if eligible capacity is limited to 100 MW, the subproblem has one 1 h step with unit weight, the rate is 40 per MWh, and all other operating costs are nonnegative. These are conditions for the bound, not general defaults.

A conservative bound under those nonnegative-cost assumptions is:

```math
\mathrm{LB}_{p,w} = -\omega_w \sum_e r_{e,p}\overline{K}_e \sum_{t\in w} a_{e,t},
```

where ``\overline{K}_e`` is an enforced capacity limit and ``a_{e,t}`` is availability. The bound must hold for every permitted capacity plan. For expandable resources, the `max_capacity` input must be enforced by `MaxCapacityConstraint`; flow must also be bounded by `CapacityConstraint`. A parameter value alone is not a proof of a capacity limit. If capacity limits are disabled, derive a valid bound from other enforced limits. Additional negative costs or revenues require a new bound.

The interface multiplies each input bound by ``\mathrm{DF}_p\mathrm{PVAF}_p/S^2`` before setting the existing Benders lower-bound expression. When the mapping is supplied, provide an array for every modeled period. Myopic restarts use the original period index: a restart at period 2 reads key `"2"`.

!!! warning "Automatic subproblem slacks"
    Both Monolithic and Benders support positive flow credits. With positive flow credits, Benders requires `IncludeSubproblemSlacksAutomatically=false`. The existing automatic-slack penalty has not been validated for negative operating costs. Ensure that the hard-constraint subproblems are feasible; setting `ExpectFeasibleSubproblems=true` does not itself establish feasibility.

Macro validates the bound format and finite values, but does not derive or prove a bound. A Benders model with positive flow credits and no bound mapping produces an error. Models without flow credits retain the existing default when this mapping is omitted.

## [Multiple Periods](@id flow_credit_periods)

Use a distinct resource ID for each vintage that needs separate accounting. Prepare each period's scalar rate externally. Preserve a rate during the assumed credit period and set it to zero after expiry. Macro does not infer eligibility, commissioning dates, or credit expiry from resource names or tags.

The rate stays constant within each investment period. Expiry partway through a period is not modeled as a separate annual cash-flow schedule. Refine the period structure when different years need different rates.

## [Outputs](@id flow_credit_outputs)

The cost breakdown files include a negative `FlowCredit` category. The separate [Flow Credit Payments Output](@ref manual-outputs-flow_credit) reports nonnegative payments by period, resource, and edge. It retains vintage identity when resources share the same region and asset type.

The cost total already includes the credit. Do not subtract the payment output again. Lower net model cost includes the subsidy transfer and does not imply an equal reduction in resource cost.
