# [Investment Credits](@id user_investment_credit)

## Contents

[Overview](@ref investment_credit_overview) | [Configure a Credit](@ref investment_credit_input) | [Accounting](@ref investment_credit_accounting) | [Multiple Periods](@ref investment_credit_periods) | [Outputs](@ref investment_credit_outputs)

## [Overview](@id investment_credit_overview)

An investment credit reduces the investment cost of new capacity by a fixed share. Investment tax credits (ITCs) are one application. Users choose the purpose and the eligible components. Macro records the credit separately from the investment cost.

Enter a positive `investment_credit_rate` when a credit applies, or zero when it does not. The model subtracts the credit once from the investment cost. Keep `investment_cost` at its value before the credit.

!!! warning "Avoid counting the credit twice"
    If an input previously included a credit as a lower `investment_cost`, restore the cost before setting `investment_credit_rate`.

## [Configure a Credit](@id investment_credit_input)

`investment_credit_rate` is a finite scalar between 0 and 1: the share of the investment cost of new capacity returned as a credit. Its default is `0.0`. Strings, Boolean values, arrays, values outside ``[0, 1]`` and non-finite values are rejected.

For a VRE asset, add the rate to `edges.edge`:

```json
{
    "edges": {
        "edge": {
            "investment_cost": 900000.0,
            "investment_credit_rate": 0.3
        }
    }
}
```

The rate can be set on any edge or storage with capacity (`has_capacity = true`); a positive rate on a component without capacity is an error. For a Battery, set it on `storage`, `discharge_edge` or both, as for `investment_cost`. There is no asset-type or commodity whitelist.

The credit applies only to new capacity. Existing capacity, and components that cannot expand, receive no credit. The rate is dimensionless, so parameter scaling leaves it unchanged.

### A lower cost of capital as a credit

A credit can also represent new capacity financed at a lower cost of capital ``w^{der}`` than the component's `wacc` ``w``, over the same `capital_recovery_period` ``N``. The credit is then the share of the annuity saved:

```math
r = 1 - \frac{\mathrm{CRF}(w^{der}, N)}{\mathrm{CRF}(w, N)}.
```

This gives the same objective as setting `wacc` to ``w^{der}``, while the outputs keep the investment cost at ``w`` and report the saving as a credit.

## [Accounting](@id investment_credit_accounting)

Let ``r_y`` be the rate of component ``y`` and ``K_y`` its new capacity. The credit uses the same investment cost attribute as the investment cost term, so it follows its annuity, discounting and Myopic adjustments:

```math
\text{eInvestmentFixedCost} \mathrel{+}= (1 - r_y)\, \text{pv\_period\_investment\_cost}(y)\, K_y.
```

The credit does not add decision variables or constraints. Payment reports calculate the credit separately from the solved new capacity and the supplied rate. This separate reporting does not add the credit to the objective again.

The credit belongs to the planning problem. Operating costs are unchanged, so Benders models need no additional settings.

## [Multiple Periods](@id investment_credit_periods)

The rate in period ``p`` applies only to the new capacity built in period ``p``. Each vintage therefore keeps the rate of the period in which it was built, and capacity carried over from earlier periods is not credited again. Separate resource IDs per vintage are not needed. Set each period's rate in that period's inputs, and set it to zero when the credit no longer applies. Macro does not infer eligibility or expiry from resource names or tags.

## [Outputs](@id investment_credit_outputs)

The cost breakdown files include a negative `InvestmentCredit` category. The separate [Investment Credits Output](@ref manual-outputs-investment_credit) reports the credit by period, resource and component.

The cost total already includes the credit. Do not subtract the credit output again. A lower net model cost includes the subsidy transfer and does not imply an equal reduction in resource cost.
