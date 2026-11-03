# [PTC Payments Output](@id manual-outputs-ptc)

## Contents

[Overview](@ref manual-outputs-ptc-overview) | [Columns](@ref manual-outputs-ptc-columns) | [Accounting](@ref manual-outputs-ptc-accounting) | [Configuration](@ref manual-outputs-ptc-configuration) | [See Also](@ref manual-outputs-ptc-see-also)

## [Overview](@id manual-outputs-ptc-overview)

**File:** `ptc_payments.csv`

Macro writes this file in each period's results directory. It reports nonnegative production tax credit payments, with one row per resource and eligible edge. Monolithic and Benders use the same columns. Benders combines representative subperiods without merging different resource IDs.

The file uses a fixed long format, independent of `OutputLayout`. Zero-rate edges are omitted. If all rates are zero, the file contains only the header. An edge with a positive rate and no generation can have a zero-payment row.

## [Columns](@id manual-outputs-ptc-columns)

| Column | Type | Description |
|---|---|---|
| `period` | Integer | Original investment-period index |
| `resource_id` | String | Asset ID, retaining vintage identity |
| `edge_id` | String | Eligible electricity edge ID |
| `zone` | String | Region from the edge's endpoint location |
| `type` | String | Asset type |
| `tags` | String | Asset tags separated by `\|` |
| `ptc_rate` | Float64 | Original monetary units per MWh |
| `eligible_generation_mwh` | Float64 | Annual weighted eligible generation in MWh |
| `annual_payment` | Float64 | Annual weighted payment in original monetary units |
| `period_payment` | Float64 | Payment over the investment period, without discounting |
| `discounted_payment` | Float64 | Payment discounted to the case start |

All values are restored from parameter scaling. The word *annual* describes the supplied time weights; short cases are not automatically expanded to a full year.

## [Accounting](@id manual-outputs-ptc-accounting)

Macro calculates payments from solved eligible generation, time weights, and the input rate. It applies scaling and financial factors during output processing.

For a resource with rate ``r`` and annual weighted generation ``G``:

```math
\begin{aligned}
P^{\mathrm{annual}} &= rG, \\
P^{\mathrm{period}} &= L_p P^{\mathrm{annual}}, \\
P^{\mathrm{discounted}} &= \mathrm{DF}_p\mathrm{PVAF}_pP^{\mathrm{annual}}.
\end{aligned}
```

Here ``L_p`` is the period length in years. The discount factor and annuity factor follow [Financial Assumptions](../Financial_assumptions.md).

The sum of `discounted_payment` equals the magnitude of the negative `PTC` category in the discounted cost breakdown. The sum of `period_payment` corresponds to the undiscounted `PTC` category. The system cost total already includes this subtraction.

## [Configuration](@id manual-outputs-ptc-configuration)

Set `ptc_rate` on an eligible electricity capacity edge as described in [Electricity Production Tax Credits](@ref user_ptc). Output is written through the ordinary results workflow; it requires no separate output switch.

## [See Also](@id manual-outputs-ptc-see-also)

- [Electricity Production Tax Credits](@ref user_ptc)
- [Costs Output](@ref manual-outputs-costs)
- [Output Directory Structure](@ref manual-outputs-directory)
- [Edges](@ref)
