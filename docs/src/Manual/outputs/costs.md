# [Costs Output](@id manual-outputs-costs)

## Contents

[Overview](@ref "manual-outputs-costs-overview") | [System-Level Cost Files](@ref "manual-outputs-costs-system") | [Breakdown Cost Files](@ref "manual-outputs-costs-breakdown") | [Cost Categories](@ref "manual-outputs-costs-categories") | [Configuration](@ref "manual-outputs-costs-configuration") | [Assumptions](@ref "manual-outputs-costs-assumptions") | [Examples](@ref "manual-outputs-costs-examples") | [See Also](@ref "manual-outputs-costs-see-also")

## [Overview](@id manual-outputs-costs-overview)

**Files:** `costs.csv`, `undiscounted_costs.csv`, `costs_by_type.csv`, `costs_by_zone.csv`, `undiscounted_costs_by_type.csv`, `undiscounted_costs_by_zone.csv`

Macro writes six cost output files after each solve. Together they provide a complete picture of the system's total expenditure, broken down by discounting status, cost category, asset type, and zone.

- **`costs.csv`** and **`undiscounted_costs.csv`** — system-wide totals (three rows: fixed, variable, total)
- **`costs_by_type.csv`** and **`undiscounted_costs_by_type.csv`** — breakdown by asset type and cost category
- **`costs_by_zone.csv`** and **`undiscounted_costs_by_zone.csv`** — breakdown by zone and cost category

All values represent costs for the **entire modeled period**, not annualized values.

## [System-Level Cost Files](@id manual-outputs-costs-system)

### `costs.csv` (discounted) and `undiscounted_costs.csv`

These files contain exactly three rows — one for fixed costs, one for variable costs, and one for the total. All metadata columns are set to `"all"` or `"missing"` because the values are system-wide aggregates with no per-asset or per-zone breakdown.

| Column | Type | Description |
|---|---|---|
| `type` | String | Always `"Cost"` |
| `variable` | String | Cost type: see table below |
| `value` | Float64 | Cost value in the model's monetary units |

#### `variable` values in `costs.csv` (discounted)

| `variable` | Description |
|---|---|
| `DiscountedFixedCost` | Present value of all fixed costs (investment annuities + fixed O&M) |
| `DiscountedVariableCost` | Present value of all variable costs (variable O&M, fuel, startup, NSD penalties) |
| `DiscountedTotalCost` | Sum of `DiscountedFixedCost` + `DiscountedVariableCost` (the objective value) |

#### `variable` values in `undiscounted_costs.csv`

| `variable` | Description |
|---|---|
| `FixedCost` | Undiscounted total fixed costs |
| `VariableCost` | Undiscounted total variable costs |
| `TotalCost` | Sum of `FixedCost` + `VariableCost` |

## [Breakdown Cost Files](@id manual-outputs-costs-breakdown)

### `costs_by_type.csv` and `undiscounted_costs_by_type.csv`

These files break costs down by **asset type** (e.g., `ThermalPower{NaturalGas}`, `Battery`, `VRE`) and [cost category](@ref "manual-outputs-costs-categories") (e.g., `Investment`, `Fuel`). A final row with `type = "Total"` gives the system-wide sum for each category.

| Column | Type | Description |
|---|---|---|
| `type` | String | Asset type string, or `"Total"` for the system-wide sum |
| `category` | String | Cost category (see [Cost Categories](@ref "manual-outputs-costs-categories")) |
| `value` | Float64 | Cost value for this asset type and category |

### [`costs_by_zone.csv` and `undiscounted_costs_by_zone.csv`](@id manual-outputs-costs-breakdown-zone)

These files break costs down by **zone** (location) and [cost category](@ref "manual-outputs-costs-categories"). A final row with `zone = "Total"` gives the system-wide sum.

| Column | Type | Description |
|---|---|---|
| `zone` | String | Zone (location) name, or `"Total"` for the system-wide sum |
| `category` | String | Cost category (see [Cost Categories](@ref "manual-outputs-costs-categories")) |
| `value` | Float64 | Cost value for this zone and category |

!!! note "Discounted vs. undiscounted breakdown files"
    `costs_by_type.csv` and `costs_by_zone.csv` report discounted costs. Their undiscounted counterparts (`undiscounted_costs_by_type.csv`, `undiscounted_costs_by_zone.csv`) have the same structure but values are not discounted to present value.

## [Cost Categories](@id manual-outputs-costs-categories)

The `category` column in the breakdown files takes one of the following values. The same category names appear in both the discounted (`costs_by_type.csv`, `costs_by_zone.csv`) and undiscounted (`undiscounted_costs_by_type.csv`, `undiscounted_costs_by_zone.csv`) files — the distinction is in how the values are computed, not in the category names themselves.

Internally, Macro splits categories into two groups that use different discounting multipliers. 

**Fixed cost categories:**

| Category | Discounted | Undiscounted |
|---|---|---|
| `Investment` | Annualized capital expenditure (CAPEX), amortized over the capital recovery period via CRF and then present-valued over the years the asset operates within the modeling horizon | Lump-sum CAPEX multiplied by the capital recovery factor (CRF) to annualize it, then multiplied by the number of years the asset operates within the modeling horizon (up to the CRP) |
| `FixedOM` | Annual fixed operations and maintenance cost, present-valued over the period length | Annual fixed operations and maintenance cost multiplied by the period length |

**Variable operating cost categories** 

All follow the same discounting structure. For each category, $C$ is the **category-specific annualized cost** computed from the representative time steps: $C = \sum_t w_t \times \text{unit cost} \times \text{flow}_t$, where $w_t$ is the subperiod weight and the unit cost varies by category (see description table below). The discounted value is $C$ multiplied by the present-value annuity factor (PVAF) for the period length and then multiplied by the period discount factor (DF). The undiscounted value is simply $C$ multiplied by the period length.

| Category | Description |
|---|---|
| `VariableOM` | Cost proportional to energy output, using the variable O&M rate per unit of flow |
| `Fuel` | Cost of fuel consumed, using the fuel price per unit of fuel flow |
| `Startup` | Cost of starting thermal generators, using the startup cost per start event |
| `NonServedDemand` | Penalty for unmet demand, using the non-served demand penalty parameter (not actual expenditure — an optimization penalty to incentivize meeting demand) |
| `Supply` | Cost of purchasing commodity supply from nodes with an associated supply price |
| `UnmetPolicyPenalty` | Penalty for violating policy constraints such as renewable portfolio standards or emission caps with slack variables (not actual expenditure — an optimization penalty) |

### Notation and Formulas

The following notation is used throughout:

| Symbol | Meaning |
|---|---|
| $DR$ | Discount rate (`DiscountRate` in `case_settings.json`) |
| $\lvert I \rvert$ | Total number of planning periods |
| $L_i$ | Period length in years for period $i$ (`PeriodLengths[i]` in `case_settings.json`) |
| $N_i$ | Years from the case start year to the start of period $i$: $N_i = \sum_{s=1}^{i-1} L_s$ |
| $M_i$ | Total years from the start of period $i$ to the end of the last period — i.e., $M_i = \sum_{s=i}^{\lvert I \rvert} L_s$ |
| $\text{CRP}$ | Capital Recovery Period — the number of years over which the capital investment is amortized into annual payments, set per component via `capital_recovery_period` in the input data (may differ from the physical asset lifetime) |
| $\text{CRF}$ | Capital Recovery Factor — converts a lump-sum CAPEX into an equivalent annual payment: $\text{CRF}(DR, N) = \dfrac{DR}{1-(1+DR)^{-N}}$ |

The **present-value annuity factor** (PVAF) converts a stream of $N$ annual payments into a present value at year 0:

$$\text{PVAF}(DR, N) = \sum_{t=1}^{N} \frac{1}{(1+DR)^t} = \frac{1-(1+DR)^{-N}}{DR} = \frac{1}{\text{CRF}(DR, N)}$$

The **period discount factor** brings a value at the start of period $p$ back to the case base year:

$$\text{DF}(DR, N_i) = \frac{1}{(1+DR)^{N_i}}$$

Note: when $DR = 0$, $\text{PVAF}(0, N) = N$, $\text{CRF}(0, N) = 1/N$, and $\text{DF}(0, N_i) = 1$.

Given these definitions, the cost categories are computed as follows:

**Fixed cost categories:**

| Category | Discounted value | Undiscounted value |
|---|---|---|
| `Investment` | $\text{CAPEX} \times \text{CRF}(DR, \text{CRP}) \times \text{PVAF}(DR,\, \min(\text{CRP},\, M_i)) \times \text{DF}(DR, N_i)$ | $\text{CAPEX} \times \text{CRF}(DR, \text{CRP}) \times \min(\text{CRP},\, M_i)$ |
| `FixedOM` | annual fixed O&M $\times\, \text{PVAF}(DR, L_i) \times \text{DF}(DR, N_i)$ | annual fixed O&M $\times\, L_i$ |

!!! note "Myopic investment cost reporting"
    In a **myopic** run, the optimizer only considers investment costs over the current period length $L_i$ (i.e., it uses $\min(\text{CRP}, L_i)$ rather than $\min(\text{CRP}, M_i)$). However, before writing outputs, Macro adds back the annuities that the myopic optimizer did not account for, so that the **reported** investment cost uses $\min(\text{CRP}, M_i)$ in both myopic and perfect-foresight runs. This adjustment enables direct cost comparisons across solution algorithms. See [Multi-Period Accounting](@ref "manual-multi-period-accounting-general-assumptions") for details.

**Variable cost categories:**

| Category | Discounted value | Undiscounted value |
|---|---|---|
| `VariableOM` | $C \times \text{PVAF}(DR, L_i) \times \text{DF}(DR, N_i)$ | $C \times L_i$ |
| `Fuel` | $C \times \text{PVAF}(DR, L_i) \times \text{DF}(DR, N_i)$ | $C \times L_i$ |
| `Startup` | $C \times \text{PVAF}(DR, L_i) \times \text{DF}(DR, N_i)$ | $C \times L_i$ |
| `NonServedDemand` | $C \times \text{PVAF}(DR, L_i) \times \text{DF}(DR, N_i)$ | $C \times L_i$ |
| `Supply` | $C \times \text{PVAF}(DR, L_i) \times \text{DF}(DR, N_i)$ | $C \times L_i$ |
| `UnmetPolicyPenalty` | $C \times \text{PVAF}(DR, L_i) \times \text{DF}(DR, N_i)$ | $C \times L_i$ |

!!! note "Zero-value categories"
    Categories with zero total cost are still included in the output. Not all categories will be non-zero for every system — for example, a system with no unit-commitment assets will have `Startup = 0` throughout.

## [Configuration](@id manual-outputs-costs-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `OutputLayout` (or `OutputLayout.Costs`) | `macro_settings.json` | `"long"` | Set to `"wide"` to pivot all cost files. For `costs.csv`/`undiscounted_costs.csv`, the three rows become a single row with variable names as columns. For the breakdown files, cost categories are pivoted to columns and a `Total` column is added. |

## [Assumptions](@id manual-outputs-costs-assumptions)

- **Period-wide totals, not annualized.** All cost values represent total costs over the entire modeled period, not an annual rate. In a single-period model this is typically one year. In a multi-period model, costs for period N represent the costs incurred over the length of that period (see `PeriodLengths` in `case_settings.json`).
- **Discounting.** Discounted costs in `costs.csv` are present values referenced to the base year of the model. The discount rate is the `DiscountRate` field in `case_settings.json`. See [Multi-Period Accounting](@ref "manual-multi-period-accounting-general-assumptions") for the full discounting formula.
- **Objective value.** `DiscountedTotalCost` in `costs.csv` equals the value of the optimization objective function (modulo any numerical scaling applied internally). Minimizing this quantity is what the optimizer does.
- **Units.** Costs are in the monetary units used in your input data (typically \$). Macro does not enforce a specific currency; it is the user's responsibility to ensure consistent units across all input cost parameters.
- **Non-served demand costs.** These are counted as variable costs in the system-level files and appear as the `NonServedDemand` category in the breakdown files. They are a penalty, not actual expenditure — they incentivize the optimizer to meet demand.
- **Supply costs.** Costs associated with commodity supply (e.g., natural gas supply nodes with a price) appear under the `Supply` category.

## [Examples](@id manual-outputs-costs-examples)

### `costs.csv` (wide format, typical single-period model)

With `OutputLayout.Costs = "wide"`, the three rows are pivoted into a single row with one column per cost variable:

| DiscountedFixedCost | DiscountedVariableCost | DiscountedTotalCost |
|---|---|---|
| 2.929e11 | 1.719e11 | 4.649e11 |

The metadata columns (`case_name`, `commodity`, `zone`, `resource_id`, `component_id`, `type`, `year`) are dropped automatically in wide format.

### `undiscounted_costs.csv` (wide format)

| FixedCost | VariableCost | TotalCost |
|---|---|---|
| 2.929e11 | 1.719e11 | 4.649e11 |

### `costs_by_type.csv` (default long format)

| type | category | value |
|---|---|---|
| ThermalPower{NaturalGas} | Investment | 1.20e10 |
| ThermalPower{NaturalGas} | FixedOM | 8.50e9 |
| ThermalPower{NaturalGas} | Fuel | 3.10e10 |
| Battery | Investment | 5.40e10 |
| Battery | FixedOM | 2.10e9 |
| VRE | Investment | 7.80e10 |
| VRE | FixedOM | 1.30e9 |
| Total | Investment | 2.54e11 |
| Total | Fuel | 3.10e10 |

### `costs_by_type.csv` (wide format)

With `OutputLayout.Costs = "wide"`, cost categories are pivoted to columns and a `Total` column is added:

| type | Investment | FixedOM | VariableOM | Fuel | Startup | NonServedDemand | Supply | UnmetPolicyPenalty | Total |
|---|---|---|---|---|---|---|---|---|---|
| ThermalPower{NaturalGas} | 1.20e10 | 8.50e9 | 0.0 | 3.10e10 | 0.0 | 0.0 | 0.0 | 0.0 | 5.15e10 |
| Battery | 5.40e10 | 2.10e9 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 5.61e10 |
| VRE | 7.80e10 | 1.30e9 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 7.93e10 |
| Total | 2.54e11 | 1.19e10 | 0.0 | 3.10e10 | 0.0 | 0.0 | 0.0 | 0.0 | 2.97e11 |

### `costs_by_zone.csv` (default long format)

| zone | category | value |
|---|---|---|
| SE | Investment | 9.80e10 |
| SE | FixedOM | 3.20e9 |
| MIDAT | Investment | 8.10e10 |
| NE | Investment | 7.60e10 |
| Total | Investment | 2.54e11 |

### `costs_by_zone.csv` (wide format)

| zone | Investment | FixedOM | VariableOM | Fuel | Startup | NonServedDemand | Supply | UnmetPolicyPenalty | Total |
|---|---|---|---|---|---|---|---|---|---|
| SE | 9.80e10 | 3.20e9 | 0.0 | 1.20e10 | 0.0 | 0.0 | 0.0 | 0.0 | 1.13e11 |
| MIDAT | 8.10e10 | 4.50e9 | 0.0 | 1.10e10 | 0.0 | 0.0 | 0.0 | 0.0 | 9.65e10 |
| NE | 7.60e10 | 4.20e9 | 0.0 | 8.00e9 | 0.0 | 0.0 | 0.0 | 0.0 | 8.82e10 |
| Total | 2.54e11 | 1.19e10 | 0.0 | 3.10e10 | 0.0 | 0.0 | 0.0 | 0.0 | 2.97e11 |

### Reading Costs in Julia

```julia
using CSV, DataFrames

costs = CSV.read("results/costs.csv", DataFrame)
costs_by_type = CSV.read("results/costs_by_type.csv", DataFrame)

# Get total investment cost
total_investment = costs_by_type[costs_by_type.type .== "Total" .&& costs_by_type.category .== "Investment", :value][1]
```

## [See Also](@id manual-outputs-costs-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Capacity Output](@ref "manual-outputs-capacity") — the capacity decisions that drive investment costs
- [Financial Assumptions](@ref "Investment costs") — Capital Recovery Factor calculation and WACC
- [Multi-Period Accounting](@ref "manual-multi-period-accounting-general-assumptions") — present-value discounting across periods
- [Non-Served Demand Output](@ref "manual-outputs-nsd") — non-served demand penalty costs
