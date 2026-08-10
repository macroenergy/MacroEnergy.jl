# [Benders Convergence Output](@id manual-outputs-benders)

## Contents

[Overview](@ref "manual-outputs-benders-overview") | [Columns](@ref "manual-outputs-benders-columns") | [Configuration](@ref "manual-outputs-benders-configuration") | [Assumptions](@ref "manual-outputs-benders-assumptions") | [Examples](@ref "manual-outputs-benders-examples") | [See Also](@ref "manual-outputs-benders-see-also")

## [Overview](@id manual-outputs-benders-overview)

**File:** `benders_convergence.csv`

**Condition:** Only written when `SolutionAlgorithm = "Benders"` in `case_settings.json`.

`benders_convergence.csv` records the convergence history of the Benders decomposition algorithm. It is written at the case root (alongside the `results_period_N/` directories), not inside any individual period's results directory.

Benders decomposition is an iterative algorithm that alternates between a planning (investment) master problem and a set of operational subproblems. At each iteration, the algorithm computes a **lower bound (LB)** on the optimal cost (from the master problem) and an **upper bound (UB)** (from combining the master and subproblem solutions). Convergence is declared when the **gap** between LB and UB falls below the configured tolerance.

This file is primarily useful for diagnosing slow convergence or verifying that the algorithm converged properly.

!!! note "Outer directory file"
    `benders_convergence.csv` is written inside the **outer results directory** (e.g., `results_001/benders_convergence.csv`), alongside `settings.json` and the `results_period_N/` subdirectories. It covers the full Benders solve across all periods.

## [Columns](@id manual-outputs-benders-columns)

| Column | Type | Description |
|---|---|---|
| `Iter` | Int | Benders iteration number (1-based) |
| `CPU_Time` | Float64 | Elapsed CPU time in seconds at the end of this iteration |
| `LB` | Float64 | Lower bound on the optimal objective value at this iteration (from the master problem) |
| `UB` | Float64 | Upper bound on the optimal objective value at this iteration (from the combined master + subproblem solution) |
| `Gap` | Float64 | Optimality gap: `(UB - LB) / abs(UB)`, as a fraction (e.g., `0.001` = 0.1% gap) |
| `Status` | String | Solver termination status (written on the **first row only**); indicates why the algorithm stopped (e.g., `"OPTIMAL"`, `"NONE"`, `"NEGATIVE GAP"`, `"TIMELIMIT"`, `"MAXITER"`) |

## [Configuration](@id manual-outputs-benders-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `SolutionAlgorithm` | `case_settings.json` | `"Monolithic"` | Set to `"Benders"` to use Benders decomposition; this is required for `benders_convergence.csv` to be written. |
| `ConvTol` | `benders_settings.json` | `0.001` | Convergence tolerance (fraction gap). The algorithm stops when `Gap ≤ ConvTol`. |
| `MaxIter` | `benders_settings.json` | `50` | Maximum number of Benders iterations. If reached, `Status = "MAXITER"`. |
| `MaxCpuTime` | `benders_settings.json` | `7200` | Maximum CPU time in seconds. If reached, `Status = "TIMELIMIT"`. |

## [Assumptions](@id manual-outputs-benders-assumptions)

- **Monotone bounds.** The lower bound (LB) is non-decreasing across iterations; the upper bound (UB) is non-increasing (in theory). Violations of this monotonicity may indicate numerical issues (e.g., numerical tolerance problems in the LP solver).
- **Gap calculation.** The gap is computed as `(UB - LB) / abs(UB)`. A `Gap` of `0.001` (0.1%) is the default convergence criterion. The `ConvTol` parameter in `benders_settings.json` controls this threshold.

## [Examples](@id manual-outputs-benders-examples)

### Example `benders_convergence.csv`

| Iter | CPU\_Time | LB | UB | Gap | Status |
|---|---|---|---|---|---|
| 1 | 12.3 | 1.20e10 | 5.40e11 | 0.978 | OPTIMAL |
| 2 | 24.7 | 2.85e11 | 4.12e11 | 0.308 | |
| 3 | 36.1 | 3.40e11 | 3.85e11 | 0.117 | |
| 4 | 48.9 | 3.62e11 | 3.76e11 | 0.037 | |
| 5 | 61.2 | 3.70e11 | 3.73e11 | 0.008 | |
| 6 | 74.5 | 3.71e11 | 3.72e11 | 0.003 | |
| 7 | 88.1 | 3.715e11 | 3.718e11 | 0.0008 | |

In this example, the algorithm converged in 7 iterations with a final gap below the default 0.1% tolerance. The `Status = "OPTIMAL"` appears in the first row.

### Reading Convergence History

```julia
using CSV, DataFrames, Plots

convergence = CSV.read("benders_convergence.csv", DataFrame)

# Plot convergence
plot(convergence.Iter, convergence.Gap .* 100,
     xlabel="Iteration", ylabel="Gap (%)",
     title="Benders Convergence", yscale=:log10,
     marker=:circle, legend=false)
hline!([0.1], linestyle=:dash, color=:red, label="Target (0.1%)")
```

### Diagnosing Convergence Issues

If `Status = "MAXITER"` or `Status = "TIMELIMIT"`, the algorithm did not converge within the allowed budget. Consider:
- Increasing `MaxIter` or `MaxCpuTime` in `benders_settings.json`
- Relaxing `ConvTol` if the final gap is acceptable for your use case
- Checking for numerical issues in the subproblem solutions (large UB swings between iterations)
- Enabling Benders stabilization (`StabParam > 0`) to accelerate convergence

## [See Also](@id manual-outputs-benders-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Settings Output](@ref "manual-outputs-settings-output") — the `settings.json` file that records Benders configuration
