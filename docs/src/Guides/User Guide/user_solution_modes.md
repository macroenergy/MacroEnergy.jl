# [Solution Modes](@id user_solution_modes)

Macro separates two independent modelling choices that together determine how a case is solved:

- **Expansion horizon** — how planning decisions across multiple investment periods are coupled. Set with `"ExpansionHorizon"` in `case_settings.json` (possible values: `"PerfectForesight"` or `"Myopic"`).
- **Solution algorithm** — the mathematical technique used to solve each optimisation problem. Set with `"SolutionAlgorithm"` in `case_settings.json` (possible values: `"Monolithic"` or `"Benders"`).

Combining one choice from each axis gives four solution modes:

| | **Monolithic** | **Benders** |
|:--|:--|:--|
| **Perfect Foresight** | All periods solved together as a single LP/MIP. The planner sees all future costs and constraints simultaneously. | The same perfect-foresight problem is decomposed: a planning master problem iterates with operational subproblems via Benders cuts. |
| **Myopic** | Each investment period is solved as a standalone LP/MIP. Capacity decisions from period *t* are fixed as constraints for period *t+1*. | Each investment period is solved with Benders decomposition. Capacity decisions are carried forward myopically between periods. |

The sections below describe each mode in detail: when to choose it, how to configure it, and what tradeoffs to expect.

!!! note "Default mode"
    If `"ExpansionHorizon"` and `"SolutionAlgorithm"` are omitted from `case_settings.json`, Macro defaults to **Perfect Foresight + Monolithic**.

---

In the following sections, we use the term **period** to refer to the investment periods defined by `PeriodLengths` in `case_settings.json` (e.g. 2020-2030, 2030-2040, etc.) and **subperiod** to refer to the representative time steps within each period (e.g. a set of hours or days that capture typical operational conditions) which is configured in the `system/time_data.json` file. The number of periods and subperiods can be configured independently, and both affect the size and complexity of the optimisation problems being solved.

By default, periods are only identified by their 1-based index (period 1, period 2, ...). To have Macro label periods by calendar year instead, set `"StartYear"` (e.g. `2026`) in `case_settings.json` — each period's year is then `StartYear` plus the sum of `PeriodLengths` of all preceding periods (e.g. `2026`, `2036`, `2046` for `PeriodLengths: [10, 10, 10]`). This is optional and purely for labeling: it populates the `year` column in [`capacity.csv`](@ref "manual-outputs-capacity") and the column suffixes in [`capacity_summary.csv`](@ref "manual-outputs-capacity-summary"), but has no effect on the optimization itself.

For illustration purposes, in the descriptions below we assume a case with 3 investment periods of 10 years each, but the concepts apply to any number of periods and lengths.

## [Perfect Foresight + Monolithic](@id pf_monolithic)

### Concept

In this mode all investment periods are optimised simultaneously in a single model. The planner has complete knowledge of future costs, demands, and technology availability across all periods. This is the classical formulation used in most long-term energy system models.

Because all periods are linked in one model, the solver sees the full intertemporal trade-offs — for example, deferring investment in period 1 to take advantage of cheaper technology in period 3. The result is the globally optimal investment plan under perfect foresight.

### Configuration

**`case_settings.json`**

```json
{
    "SolutionAlgorithm": "Monolithic",
    "ExpansionHorizon": "PerfectForesight",
    "PeriodLengths": [10, 10, 10],
    "DiscountRate": 0.05
}
```

**`run.jl`**

```julia
using MacroEnergy

(case, solution) = run_case(@__DIR__);
```

The returned `solution` is a JuMP `Model` object. The HiGHS optimizer is used by default. To use a different solver:

```julia
using MacroEnergy
using Gurobi

(case, solution) = run_case(
    @__DIR__;
    optimizer            = Gurobi.Optimizer,
    optimizer_attributes = ("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3)
);
```

where Gurobi will use the barrier method without crossover and an optimality tolerance of 0.001. 

### Notes

- Best choice for small to medium cases with few periods and limited sectors.
- Memory and solve time scale with the total number of time steps × assets × periods.
- If the model has integer investment variables, solve time may increase significantly with the number of periods.

---

## [Perfect Foresight + Benders](@id pf_benders)

### Concept

This mode solves the same perfect-foresight problem as above but uses Benders decomposition to split it into a compact **planning master problem** (investment decisions only) and a set of **operational subproblems** (one per representative subperiod). The master problem and subproblems iterate: each Benders iteration adds cuts to the master problem that tighten its representation of operational costs.

The algorithm terminates when the gap between the upper bound (from the subproblems) and the lower bound (from the master problem) falls below `ConvTol`. Because subproblems are independent of each other, they can be solved in parallel, making this approach tractable for cases too large to handle monolithically. Note: the subproblems belong to all periods simultaneously, so this mode still assumes perfect foresight across the full horizon.

### Configuration

**`case_settings.json`**

```json
{
    "SolutionAlgorithm": "Benders",
    "ExpansionHorizon": "PerfectForesight",
    "PeriodLengths": [10, 10, 10],
    "DiscountRate": 0.05
}
```

**`settings/benders_settings.json`**

Macro automatically loads this file from `settings/benders_settings.json` inside the case directory if it exists. A minimal configuration:

```json
{
    "MaxIter": 100,
    "ConvTol": 1e-3,
    "MaxCpuTime": 7200,
    "Distributed": true
}
```

**`run.jl`**

```julia
using MacroEnergy
using HiGHS

(case, solution) = run_case(
    @__DIR__;
    planning_optimizer              = HiGHS.Optimizer,
    subproblem_optimizer            = HiGHS.Optimizer,
    planning_optimizer_attributes   = ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3),
    subproblem_optimizer_attributes = ("solver" => "ipm", "run_crossover" => "on",  "ipm_optimality_tolerance" => 1e-3)
);
```

The planning and subproblem optimizers can be configured independently — it is common to use an interior-point method without crossover for the planning problem and IPM with crossover for the subproblems. The returned `solution` is a `BendersModel` object; after solving, its `convergence` field holds iteration history, lower and upper bounds, and termination status. An output file `benders_convergence.csv` is also written to the results directory.

!!! tip "Parallel subproblems"
    For large cases, set `"Distributed": true` in `benders_settings.json` to solve subproblems in parallel across multiple worker processes. Macro automatically spawns and cleans up workers.

To run the case with Gurobi instead of HiGHS, change the optimizers and attributes in `run.jl`:

```julia
using MacroEnergy
using Gurobi

(case, solution) = run_case(
    @__DIR__;
    planning_optimizer              = Gurobi.Optimizer,
    subproblem_optimizer            = Gurobi.Optimizer,
    planning_optimizer_attributes   = ("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3),
    subproblem_optimizer_attributes = ("Method" => 2, "Crossover" => 1, "BarConvTol" => 1e-3)
);
```

### Notes

- The planning master problem is smaller than the full model — it contains only investment variables and Benders cuts.
- Convergence speed depends on the structure of the model, number of subperiods, stabilisation parameters (`StabParam`, `StabDynamic`), and solver tolerance settings.

---

## [Myopic + Monolithic](@id myopic_monolithic)

### Concept

In the myopic mode each investment period is optimised independently as a standalone model, without knowledge of future periods. After a period is solved, its capacity decisions are passed forward as fixed constraints for the next period — existing infrastructure, retirements, and any newly built capacity are all locked in before the next period begins. This mimics a real-world planning process where decision-makers optimise only for the near term.

With the Monolithic algorithm each period's model is solved as a single LP or MIP, using the same formulation as Perfect Foresight + Monolithic but scoped to a single period.

### Configuration

**`case_settings.json`**

```json
{
    "SolutionAlgorithm": "Monolithic",
    "ExpansionHorizon": "Myopic",
    "PeriodLengths": [10, 10, 10],
    "DiscountRate": 0.05,
    "MyopicSettings": {
        "ReturnModels": false,
        "StopAfterPeriod": 3
    }
}
```

`MyopicSettings` is optional — all fields have defaults. The most commonly set fields are:

| Field | Default | Description |
|:--|:--|:--|
| `ReturnModels` | `false` | If `true`, the solved model for each period is kept in memory and returned in `MyopicResults.results`. |
| `StopAfterPeriod` | `Inf` | Stop the myopic loop after this period index. Useful for staged runs on a cluster. |
| `WriteModelLP` | `false` | If `true`, write an LP file for each period's model. |
| `Restart.enabled` | `false` | If `true`, resume a previous run from a specified period (see below). |

**`run.jl`**

```julia
using MacroEnergy

(case, solution) = run_case(@__DIR__);
```

As before, the HiGHS optimizer is used by default. The returned `solution` is a `MyopicResults` object. When `ReturnModels` is `true`, `solution.results` holds a `Vector` of per-period JuMP `Model` objects; otherwise it is `nothing`. Results for each period are written immediately after that period is solved into subfolders `results_period_1/`, `results_period_2/`, etc.

To use a different solver, specify it in `run.jl`:

```julia
using MacroEnergy
using Gurobi

(case, solution) = run_case(
    @__DIR__;
    optimizer            = Gurobi.Optimizer,
    optimizer_attributes = ("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3)
);
```

### Stop-and-go restart

For long myopic runs on a cluster you can stop after a given period and resume later. In the first job, set:

```json
"MyopicSettings": {
    "StopAfterPeriod": 2
}
```

Then in the next job, load the capacities from the previous results and continue:

```json
"MyopicSettings": {
    "StopAfterPeriod": 4,
    "Restart": {
        "enabled": true,
        "folder": "results_001",
        "from_period": 3
    }
}
```

With this configuration Macro skips periods 1 and 2 (loading their capacity results from `results_001/`) and starts solving from period 3.

### Notes

- Memory usage is proportional to a single period, not the full horizon — each period's model is discarded after writing results (unless `ReturnModels` is `true`).
- Results are written incrementally: if a run is interrupted, completed periods are already saved and can be reused in a restart.
- The myopic plan is not globally optimal — each period minimises cost given the decisions already made, without anticipating future cost trajectories.

---

## [Myopic + Benders](@id myopic_benders)

### Concept

This mode combines the myopic planning logic with Benders decomposition within each period. For every investment period a planning master problem iterates with operational subproblems — exactly as in Perfect Foresight + Benders — but scoped to that period only. Once a period converges, its capacity decisions are carried forward myopically to the next.

This is the most memory-efficient mode: it handles both a long planning horizon (many periods) and a rich operational model (many subperiods per period) that would be intractable even for a single period's monolithic model.

### Configuration

**`case_settings.json`**

```json
{
    "SolutionAlgorithm": "Benders",
    "ExpansionHorizon": "Myopic",
    "PeriodLengths": [10, 10, 10],
    "DiscountRate": 0.05,
    "MyopicSettings": {
        "ReturnModels": false,
        "StopAfterPeriod": 3
    }
}
```

**`settings/benders_settings.json`**

```json
{
    "MaxIter": 100,
    "ConvTol": 1e-3,
    "MaxCpuTime": 7200,
    "Distributed": true
}
```

**`run.jl`**

```julia
using MacroEnergy
using HiGHS

(case, solution) = run_case(
    @__DIR__;
    planning_optimizer              = HiGHS.Optimizer,
    subproblem_optimizer            = HiGHS.Optimizer,
    planning_optimizer_attributes   = ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3),
    subproblem_optimizer_attributes = ("solver" => "ipm", "run_crossover" => "on",  "ipm_optimality_tolerance" => 1e-3)
);
```

The returned `solution` is a `MyopicResults` object. When `ReturnModels` is `true`, `solution.results` holds a `Vector` of per-period `BendersModel` objects. A `benders_convergence.csv` file is written for each period in its results subfolder.

!!! tip "Stop-and-go restart"
    The stop-and-go restart feature described under [Myopic + Monolithic](@ref myopic_monolithic) works identically here: set `StopAfterPeriod` and `Restart` in `MyopicSettings`.

As before, to run with Gurobi instead of HiGHS, change the optimizers and attributes in `run.jl`:

```julia
using MacroEnergy
using Gurobi

(case, solution) = run_case(
    @__DIR__;
    planning_optimizer              = Gurobi.Optimizer,
    subproblem_optimizer            = Gurobi.Optimizer,
    planning_optimizer_attributes   = ("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3),
    subproblem_optimizer_attributes = ("Method" => 2, "Crossover" => 1, "BarConvTol" => 1e-3)
);
```

### Notes

- Benders convergence must be achieved independently for each period before moving to the next.
- Subproblems can be parallelised within each period by setting `"Distributed": true` in `benders_settings.json`.
- This is the appropriate choice when a case is both too large for a monolithic solver within a single period *and* requires myopic planning assumptions.
