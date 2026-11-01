# [Electricity Production Tax Credits](@id user_ptc)

## Contents

[Overview](@ref ptc_overview) | [Configure a Credit](@ref ptc_input) | [Accounting](@ref ptc_accounting) | [Benders Settings](@ref ptc_benders) | [Multiple Periods](@ref ptc_periods) | [Outputs](@ref ptc_outputs)

## [Overview](@id ptc_overview)

A production tax credit (PTC) reduces operating cost in proportion to actual eligible electricity production. Set the credit rate on the resource's electricity output edge. Macro records the payment separately from variable operation and maintenance cost (VOM).

Enter a positive `ptc_rate` when a credit applies, or zero when it does not. The model calculates a nonnegative payment and subtracts it once from operating cost. Keep `variable_om_cost` at its value before the credit.

!!! warning "Avoid counting the credit twice"
    If an input previously included PTC as a reduction in VOM, restore the VOM before setting `ptc_rate`. A negative `ptc_rate` is not accepted.

## [Configure a Credit](@id ptc_input)

`ptc_rate` is a finite, nonnegative scalar in monetary units per MWh. Its default is `0.0`. Supply one value per edge and investment period. Strings, Boolean values, arrays, negative numbers, and non-finite values are rejected.

For a VRE asset, add the rate to `edges.edge`:

```json
{
    "edges": {
        "edge": {
            "variable_om_cost": 3.0,
            "ptc_rate": 40.0
        }
    }
}
```

This is an asset input fragment. For ThermalPower, use `edges.elec_edge`. Check the electricity edge name for other asset types. Do not set the rate on fuel or emissions edges.

A positive rate requires a unidirectional `Electricity` edge with `has_capacity=true`. This check verifies the edge structure; it does not establish policy eligibility. Input preparation must keep ineligible production, transmission, and storage discharge at zero PTC. Asset tags and commodity type do not automatically grant eligibility.

## [Accounting](@id ptc_accounting)

Let ``r_{e,p}`` be the rate for edge ``e`` in investment period ``p``, ``q_{e,t}`` its electricity production, and ``\omega_{w(t)}`` the representative-subperiod weight. The annual weighted payment is:

```math
P_p = \sum_e \sum_t \omega_{w(t)} r_{e,p} q_{e,t}.
```

Macro follows the existing VOM flow and time-weight convention. The native input workflow uses 1 h steps, so MW flow and MWh production have the same numerical value for each step. Payments use actual generation; unused capacity and curtailed availability receive no payment.

The annual net operating cost is:

```math
C^{\mathrm{net}}_{\mathrm{op},p} = C^{\mathrm{original}}_{\mathrm{op},p} - P_p.
```

The existing financial path then applies the period discount factor and present-value annuity factor. PTC does not add decision variables or constraints. It works with zero VOM and with both UC and non-UC electricity edges. Fuel and startup costs retain their existing calculations.

Parameter scaling divides both the rate and electricity flow by ``S``, so model payments are divided by ``S^2``. Native output restores the original units once. Do not rescale those output values again.

The term *annual* follows the supplied time weights. A case containing 168 h with unit weights represents those 168 h; Macro does not automatically multiply it to 8,760 h. See [Financial Assumptions](../../Manual/Financial_assumptions.md) and [Costs Output](@ref manual-outputs-costs) for the existing cost conventions.

## [Benders Settings](@id ptc_benders)

PTC can make net operating cost negative. A zero operating-cost lower bound is therefore not assumed to be valid for Benders models with positive PTC.

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

where ``\overline{K}_e`` is an enforced capacity limit and ``a_{e,t}`` is availability. The bound must hold for every permitted capacity plan. For expandable resources, the `max_capacity` input must be enforced by `MaxCapacityConstraint`; generation must also be bounded by `CapacityConstraint`. A parameter value alone is not a proof of a capacity limit. Additional negative costs or revenues require a new bound.

The interface multiplies each input bound by ``\mathrm{DF}_p\mathrm{PVAF}_p/S^2`` before setting the existing Benders lower-bound expression. When the mapping is supplied, provide an array for every modeled period. Myopic restarts use the original period index: a restart at period 2 reads key `"2"`.

!!! warning "Automatic subproblem slacks"
    Positive PTC is supported by both Monolithic and Benders. With positive PTC, Benders requires `IncludeSubproblemSlacksAutomatically=false`. The existing automatic-slack penalty has not been validated for negative operating costs. Ensure that the hard-constraint subproblems are feasible; setting `ExpectFeasibleSubproblems=true` does not itself establish feasibility.

Macro validates the bound format and finite values, but does not derive or prove a bound. A Benders model with positive PTC and no bound mapping produces an error. Models without PTC retain the existing default when this mapping is omitted.

## [Multiple Periods](@id ptc_periods)

Use a distinct resource ID for each vintage that needs separate accounting. Prepare each period's scalar rate externally. Preserve a rate during the assumed credit period and set it to zero after expiry. Macro does not infer eligibility, commissioning dates, or credit expiry from resource names or tags.

The rate stays constant within each investment period. Expiry partway through a period is not modeled as a separate annual cash-flow schedule. Refine the period structure when different years need different rates.

## [Outputs](@id ptc_outputs)

The cost breakdown files include a negative `PTC` category. The separate [PTC Payments Output](@ref manual-outputs-ptc) reports nonnegative payments by period, resource, and edge. It retains vintage identity when resources share the same region and asset type.

The cost total already includes the credit. Do not subtract the payment output again. Lower net model cost includes the subsidy transfer and does not imply an equal reduction in resource cost.
