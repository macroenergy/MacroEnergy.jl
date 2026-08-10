# [Dual Values Output](@id manual-outputs-duals)

## Contents

[Overview](@ref "manual-outputs-duals-overview") | [Balance Duals](@ref "manual-outputs-duals-balance") | [CO₂ Cap Duals](@ref "manual-outputs-duals-co2") | [Configuration](@ref "manual-outputs-duals-configuration") | [Assumptions](@ref "manual-outputs-duals-assumptions") | [Examples](@ref "manual-outputs-duals-examples") | [See Also](@ref "manual-outputs-duals-see-also")

## [Overview](@id manual-outputs-duals-overview)

**Files:** `balance_duals.csv`, `co2_cap_duals.csv`

**Condition:** Both files are written only when `DualExportsEnabled = true` (the default) in `macro_settings.json`.

Dual values (also called shadow prices or Lagrange multipliers) are the marginal costs associated with binding constraints in the optimization. Macro exports duals for two types of constraints:

1. **`balance_duals.csv`** — shadow prices of the commodity balance equations at every node (locational marginal prices)
2. **`co2_cap_duals.csv`** — shadow prices of CO₂ cap constraints (carbon prices)

!!! note "LP relaxation required for duals"
    Dual values are only available for linear programs (LPs). If your model uses integer variables (e.g., `integer_decisions = true` on any edge, or unit commitment), the LP relaxation duals will be used.

## [Balance Duals](@id manual-outputs-duals-balance)

### File: `balance_duals.csv`

Balance duals are the shadow prices of the **demand balance constraint** at each node — the constraint that requires commodity inflows to equal outflows plus demand at every time step (called `BalanceConstraint` in Macro). In power systems, this is the **Locational Marginal Price (LMP)**: the marginal cost of serving one additional unit of demand at that node and time.

### Format

`balance_duals.csv` is always in **wide format**:
- **Rows:** one row per representative time step (ordered 1 to T, implicit — no explicit `time` column)
- **Columns:** one column per node ID

The node IDs in the column headers match the `component_id` values in other output files.

### Interpretation

The value in column `node_X` at row `t` is the shadow price of the balance constraint at `node_X` at time step `t`. It represents:

- The marginal cost of delivering one additional unit of the node's commodity at that time and location (i.e., the LMP for electricity nodes)
- The system-marginal value of that commodity at that node and time

!!! note "Rescaling"
    Balance duals are rescaled before writing. The raw dual from the optimizer is divided by `(subperiod_weight × discount_scaling)` to express it as a marginal cost **per unit of commodity per hour** (e.g., \$/MWh), consistent with the variable O&M and fuel cost units in your inputs.

### Nodes included

Only nodes with a demand balance equation are included (i.e., nodes that have a `BalanceConstraint`). Nodes with other balance types (e.g., emissions accounting nodes with a `:co2_storage` balance) are excluded.

## [CO₂ Cap Duals](@id manual-outputs-duals-co2)

### File: `co2_cap_duals.csv`

CO₂ cap duals are the shadow prices of CO₂ cap budget constraints. In power systems, this is the **carbon price**: the marginal cost of relaxing the CO₂ cap by one tonne.

### Columns

| Column | Type | Description |
|---|---|---|
| `Node` | String | Identifier of the CO₂ cap node (the node on which the cap constraint is defined) |
| `CO2_Shadow_Price` | Float64 | (Discounted) shadow price of the CO₂ cap constraint (\$/tonne CO₂) — the marginal cost of tightening the cap by 1 tonne |
| `CO2_Slack` | Float64 | Total weighted penalty cost associated with the CO₂ slack variable, if slack variables are present (only written when slack is non-zero) |

### Interpretation

- **`CO2_Shadow_Price`** is the carbon price implied by the model. If the CO₂ cap is non-binding, this value is `0.0`. A non-zero value indicates that the cap is binding.
- **`CO2_Slack`** appears only when the CO₂ cap is modeled as a soft constraint (with slack variables and a penalty). It reports the total penalty cost incurred due to exceeding the cap.

## [Configuration](@id manual-outputs-duals-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `DualExportsEnabled` | `macro_settings.json` | `true` | Set to `false` to skip writing both `balance_duals.csv` and `co2_cap_duals.csv`. |
| `WriteFullTimeseries` | `case_settings.json` | `false` | When `true` and TDR is active, also write full-year `balance_duals.csv` to `full_time_series/balance_duals.csv`. |

## [Assumptions](@id manual-outputs-duals-assumptions)

- **LP models only.** Duals are only meaningful for continuous (LP) models. For MILP models, the LP relaxation duals are used.
- **Benders decomposition.** When using the Benders solver, balance duals are collected from the operational subproblems and assembled into the output file. The rescaling is applied consistently across subproblems.
- **Multi-period models.** Each period's results directory contains the duals for that period's representative time steps. The discount scaling applied to duals accounts for the time value of money, expressing all duals in present-value terms.
- **Units.** Balance duals are in (\$/unit of commodity), where the unit matches your input cost convention (typically \$/MWh for electricity, \$/tonne for mass commodities). CO₂ cap duals are in \$/tonne CO₂.
- **`balance_duals.csv` has no explicit time column.** Row order is the implicit time index (row 1 = time step 1, row 2 = time step 2, …). To match with other outputs, use row number as the time index, or join on row position.

## [Examples](@id manual-outputs-duals-examples)

### `balance_duals.csv` (wide format, excerpt)

The first row is the header with node IDs; subsequent rows are time steps.

| elec\_SE | elec\_MIDAT | elec\_NE | natgas\_SE | natgas\_MIDAT | h2\_SE | … |
|---|---|---|---|---|---|---|
| 45.2 | 48.1 | 52.3 | 3.5 | 3.5 | 12.1 | … |
| 38.7 | 41.2 | 43.9 | 3.5 | 3.5 | 12.1 | … |
| 51.8 | 55.6 | 60.2 | 3.5 | 3.5 | 12.1 | … |

### `co2_cap_duals.csv`

| Node | CO2\_Shadow\_Price | CO2\_Slack |
|---|---|---|
| co2\_sink | 150 | |

In the above example, the shadow price is ~\$150/tonne CO₂. The empty `CO2_Slack` field means no slack variable was used (the cap was modeled as a hard constraint).

### Reading Balance Duals in Julia

```julia
using CSV, DataFrames

# balance_duals.csv has no time column — add it manually
duals = CSV.read("results/balance_duals.csv", DataFrame)
duals.time = 1:nrow(duals)

# Get electricity LMPs for the SE zone
elec_SE_lmp = duals[!, [:time, :elec_SE]]

# Compute weighted average electricity price in SE
weights = CSV.read("results/time_weights.csv", DataFrame)
df = leftjoin(elec_SE_lmp, weights, on=:time)
avg_price = sum(df.elec_SE .* df.weight) / sum(df.weight)
println("Weighted avg LMP in SE: \$$(round(avg_price, digits=2))/MWh")
```

## [See Also](@id manual-outputs-duals-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Time Weights Output](@ref "manual-outputs-time-weights") — subperiod weights for computing weighted-average prices
- [Full Time Series Output](@ref "manual-outputs-full-timeseries") — full-year balance duals (when TDR is used)
- [Flows Output](@ref "manual-outputs-flows") — flows whose marginal cost the balance duals represent
- [Nodes](@ref "manual-nodes-overview") — node balance types and postprocessing (realized price)
