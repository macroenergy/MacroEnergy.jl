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