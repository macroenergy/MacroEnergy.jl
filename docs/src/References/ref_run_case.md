# Running a Macro Model

```@index
Pages = ["ref_run_case.md"]
```

## `run_case`
```@docs
MacroEnergy.run_case
```

## Solve status

Checks applied to each solved model, and the exceptions they raise. See
[Run Status File](@ref "manual-outputs-run-status") for the file these outcomes are
recorded in.

```@docs
MacroEnergy.assert_solved
MacroEnergy.solution_outcome
MacroEnergy.InfeasibleModel
MacroEnergy.UnboundedModel
MacroEnergy.SolveFailed
MacroEnergy.PeriodOutcome
```

## Run status file

```@docs
MacroEnergy.run_status_running
MacroEnergy.run_status_success
MacroEnergy.run_status_failure
MacroEnergy.write_run_status
```
## Flow credit model accounting

Each edge calls `add_flow_credit_payment!` while adding its variable costs. The helper subtracts the weighted payment directly from `eVariableCost`, including when VOM is zero. Monolithic and Benders then apply their existing operating-cost discounting.

During operation-model construction, the flow credit uses the existing edge traversal and requires no separate JuMP payment expressions. The output helpers calculate separate payments from solved flows. See [Flow Credit Payments Output](@ref manual-outputs-flow_credit).

```@docs
MacroEnergy.add_flow_credit_payment!
MacroEnergy.set_operating_cost_lower_bounds!
```
