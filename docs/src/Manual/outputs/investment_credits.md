# [Investment Credits Output](@id manual-outputs-investment_credit)

The credit file follows the `Costs` output controls. Set `WriteOutputs.Costs=false` to omit it. `OutputFormat.Costs`, or a global `OutputFormat`, selects `.csv`, `.csv.gz`, or `.parquet`. CSV is the default. Values retain full precision.

## Contents

[Overview](@ref manual-outputs-investment_credit-overview) | [Columns](@ref manual-outputs-investment_credit-columns) | [Accounting](@ref manual-outputs-investment_credit-accounting) | [Configuration](@ref manual-outputs-investment_credit-configuration) | [See Also](@ref manual-outputs-investment_credit-see-also)

## [Overview](@id manual-outputs-investment_credit-overview)

**File:** `investment_credits.csv`

Macro writes this file in each period's results directory. It reports investment credits, with one row per resource and credited component (edge or storage). Monolithic and Benders use the same columns.

The file uses a fixed long format, independent of `OutputLayout`. Zero-rate components and components that cannot expand are omitted. If all rates are zero, the file contains only the header. A component with a positive rate and no new capacity has a zero-credit row.

## [Columns](@id manual-outputs-investment_credit-columns)

| Column | Type | Description |
|---|---|---|
| `period` | Integer | Original investment-period index |
| `resource_id` | String | Asset ID, retaining vintage identity |
| `component_id` | String | Credited edge or storage ID |
| `zone` | String | Region of the component |
| `type` | String | Asset type |
| `tags` | String | Asset tags separated by `\|` |
| `commodity` | String | Commodity type of the component |
| `investment_credit_rate` | Float64 | Share of the investment cost credited |
| `credited_capacity` | Float64 | New capacity receiving the credit |
| `overnight_credit` | Float64 | Credit on the overnight investment cost, in original monetary units |
| `annual_payment` | Float64 | Credit on the annualized investment cost |
| `period_payment` | Float64 | Credit on the undiscounted investment cost of the period |
| `discounted_payment` | Float64 | Credit discounted to the case start |

All values are restored from parameter scaling.

## [Accounting](@id manual-outputs-investment_credit-accounting)

For a component with rate ``r``, investment cost ``I`` and new capacity ``K``:

```math
\begin{aligned}
P^{\mathrm{overnight}} &= r I K, \\
P^{\mathrm{annual}} &= r\, \text{annualized\_investment\_cost}\, K, \\
P^{\mathrm{period}} &= r\, \text{cf\_period\_investment\_cost}\, K, \\
P^{\mathrm{discounted}} &= \mathrm{DF}_p\, r\, \text{pv\_period\_investment\_cost}\, K.
\end{aligned}
```

The sum of `discounted_payment` equals the magnitude of the negative `InvestmentCredit` category in the discounted cost breakdown. The sum of `period_payment` corresponds to the undiscounted `InvestmentCredit` category. The system cost total already includes this subtraction.

## [Configuration](@id manual-outputs-investment_credit-configuration)

Set `investment_credit_rate` on an edge or storage with capacity, as described in [Investment Credits](@ref user_investment_credit). Output is written through the ordinary results workflow; it requires no separate output switch.

## [See Also](@id manual-outputs-investment_credit-see-also)

- [Investment Credits](@ref user_investment_credit)
- [Costs Output](@ref manual-outputs-costs)
- [Edges](@ref)
- [Storage](@ref)
