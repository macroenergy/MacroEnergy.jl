# [Flow Credit Payments Output](@id manual-outputs-flow_credit)

## Contents

[Overview](@ref manual-outputs-flow_credit-overview) | [Columns](@ref manual-outputs-flow_credit-columns) | [Accounting](@ref manual-outputs-flow_credit-accounting) | [Configuration](@ref manual-outputs-flow_credit-configuration) | [See Also](@ref manual-outputs-flow_credit-see-also)

## [Overview](@id manual-outputs-flow_credit-overview)

**File:** `flow_credits.csv`

Macro writes this file in each period's results directory. It reports nonnegative flow credit payments, with one row per resource and eligible edge. Monolithic and Benders use the same columns. Benders combines representative subperiods without merging different resource IDs.

The file uses a fixed long format, independent of `OutputLayout`. Zero-rate edges are omitted. If all rates are zero, the file contains only the header. An edge with a positive rate and no flow can have a zero-payment row.

## [Columns](@id manual-outputs-flow_credit-columns)

| Column | Type | Description |
|---|---|---|
| `period` | Integer | Original investment-period index |
| `resource_id` | String | Asset ID, retaining vintage identity |
| `edge_id` | String | Selected edge ID |
| `zone` | String | Region from the edge's endpoint location |
| `type` | String | Asset type |
| `tags` | String | Asset tags separated by `\|` |
| `commodity` | String | Commodity type carried by the edge |
| `flow_unit` | String or missing | Declared commodity quantity unit; blank when no declaration is available |
| `flow_credit_rate` | Float64 | Original monetary units per commodity quantity unit |
| `credited_flow` | Float64 | Annual weighted credited flow in the selected commodity unit |
| `annual_payment` | Float64 | Annual weighted payment in original monetary units |
| `period_payment` | Float64 | Payment over the investment period, without discounting |
| `discounted_payment` | Float64 | Payment discounted to the case start |

All values are restored from parameter scaling. The word *annual* describes the supplied time weights; short cases are not automatically expanded to a full year.

Reports retain solved values. Solver feasibility tolerances can produce small negative values near zero; the output does not clip these values.

`flow_unit` uses Macro's declared unit for the commodity, or for a declared parent commodity. The existing unit map is incomplete. A blank value does not mean MWh or tonnes; consult the case's commodity definition. The credit interface does not convert units. Do not sum `credited_flow` across different commodities or incompatible units. Payments can be aggregated in the case's common monetary unit.

## [Accounting](@id manual-outputs-flow_credit-accounting)

Macro calculates payments from solved edge flow, time weights, and the input rate. It applies scaling and financial factors during output processing.

For a resource with rate ``r`` and annual weighted flow ``G``:

```math
\begin{aligned}
P^{\mathrm{annual}} &= rG, \\
P^{\mathrm{period}} &= L_p P^{\mathrm{annual}}, \\
P^{\mathrm{discounted}} &= \mathrm{DF}_p\mathrm{PVAF}_pP^{\mathrm{annual}}.
\end{aligned}
```

Here ``L_p`` is the period length in years. The discount factor and annuity factor follow [Financial Assumptions](../Financial_assumptions.md).

The sum of `discounted_payment` equals the magnitude of the negative `FlowCredit` category in the discounted cost breakdown. The sum of `period_payment` corresponds to the undiscounted `FlowCredit` category. The system cost total already includes this subtraction.

## [Configuration](@id manual-outputs-flow_credit-configuration)

Set `flow_credit_rate` on a supported default capacity edge as described in [Flow Credits](@ref user_flow_credit). Output is written through the ordinary results workflow; it requires no separate output switch.

## [See Also](@id manual-outputs-flow_credit-see-also)

- [Flow Credits](@ref user_flow_credit)
- [Costs Output](@ref manual-outputs-costs)
- [Output Directory Structure](@ref manual-outputs-directory)
- [Edges](@ref)
