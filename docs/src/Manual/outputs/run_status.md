# [Run Status File](@id manual-outputs-run-status)

## Contents

[Overview](@ref "manual-outputs-run-status-overview") | [Location](@ref "manual-outputs-run-status-location") | [Format](@ref "manual-outputs-run-status-format") | [Configuration](@ref "manual-outputs-run-status-configuration") | [Assumptions](@ref "manual-outputs-run-status-assumptions") | [Examples](@ref "manual-outputs-run-status-examples") | [See Also](@ref "manual-outputs-run-status-see-also")

## [Overview](@id manual-outputs-run-status-overview)

**File:** `run_status.json`

Macro writes a small JSON file recording how a run ended: whether it solved, whether the solution is provably optimal, or how it failed. It exists for processes that launch Macro and cannot catch a Julia exception — a shell script, a Slurm job array, a parameter sweep driver, a workflow scheduler.

Without it, such a caller sees only the process exit code, which is `1` for *every* uncaught exception. An infeasible model, a malformed input file, and a typo in a setting are indistinguishable. The status file makes them distinguishable by reading a single field.

Exceptions are still thrown as normal. The file is a record, not a replacement for error handling.

## [Location](@id manual-outputs-run-status-location)

The run status file is written in two places:

1. **During and after the run:** at `<case_path>/run_status.json` (in the case directory itself). This is the copy to watch from outside — its path is known before the run starts, and it is written even when the run fails before any results directory exists.
2. **After a successful run:** copied into the **outer results directory** (e.g. `results_001/run_status.json`), alongside the log file and `settings.json`, so each result set carries its own record.

```
my_case/
├── run_status.json           ← written here at the start, then updated as the run ends
└── results_001/
    ├── run_status.json       ← written here after the run completes successfully
    ├── my_case.log
    ├── settings.json
    └── results/
        ├── capacity.csv
        └── ...
```

A failed run writes only the case-level file. For a Perfect Foresight run that is because no results directory is created: the solve fails before any output is written. A **Myopic** run is different — it creates its results directory up front and writes each period's outputs as it goes, so a failure in period 3 leaves a partial results directory behind, containing periods 1 and 2 but no `settings.json` and no status file. Treat a results directory without a `run_status.json` as incomplete.

## [Format](@id manual-outputs-run-status-format)

A single JSON object. Example of a Myopic run whose third period hit its time limit:

```json
{
  "status": "SUBOPTIMAL",
  "case_path": "/path/to/my_case",
  "timestamp": "2026-03-15T09:16:45.331",
  "elapsed_seconds": 281.44,
  "output_path": "/path/to/my_case/results_001",
  "termination_status": "1: OPTIMAL, 2: OPTIMAL, 3: TIME_LIMIT"
}
```

And of an infeasible one:

```json
{
  "status": "INFEASIBLE",
  "case_path": "/path/to/my_case",
  "timestamp": "2026-03-15T09:14:02.118",
  "elapsed_seconds": 118.02,
  "exception": "InfeasibleModel",
  "message": "Model (period 3) is infeasible: termination status INFEASIBLE.",
  "termination_status": "INFEASIBLE",
  "label": "period 3"
}
```

### Fields

| Field | Always present | Description |
|---|---|---|
| `status` | yes | How the run ended. See the table below. |
| `case_path` | yes | Path of the case that was run. |
| `timestamp` | yes | When the file was written. |
| `elapsed_seconds` | yes | Wall-clock seconds since the run started. `0.0` in the `RUNNING` marker. |
| `output_path` | on success | Path of the results directory, so a caller that did not choose it can find it. |
| `termination_status` | on solve outcomes | The solver's own verdict, e.g. `OPTIMAL`, `TIME_LIMIT`, `INFEASIBLE`. For a Myopic run, one comma-separated `<period>: <status>` entry per period that was solved — periods skipped by `Restart` or `StopAfterPeriod` are absent, which is why entries carry their period number. |
| `exception` | on failure | Name of the exception type, e.g. `InfeasibleModel`, `ArgumentError`. |
| `message` | on failure | The exception message, truncated at 1000 characters. The log file keeps the full text. |
| `label` | on solver failures | Which model failed, e.g. `period 3`. Empty for single-period runs. |
| `primal_status` | on `SOLVE_FAILED` | The solver's primal status, e.g. `NO_SOLUTION`. |

### Status values

| `status` | Meaning |
|---|---|
| `RUNNING` | Written before the work starts. Still present means the process never finished — see the assumptions below. |
| `OK` | Solved to optimality. Results were written. |
| `SUBOPTIMAL` | A usable solution that is not provably optimal: a limit reached with a feasible incumbent, a solver holding a feasible point it could not certify as optimal, or a Benders solve that stopped short of converging. Results were written. |
| `INFEASIBLE` | The solver proved the model has no feasible solution. |
| `INFEASIBLE_OR_UNBOUNDED` | The solver could not tell infeasible from unbounded, usually because presolve detected the problem. |
| `UNBOUNDED` | The objective is unbounded. |
| `SOLVE_FAILED` | The solver terminated without a usable solution for another reason, such as a numerical failure, or a Benders solve whose bounds crossed (`NEGATIVE GAP`). |
| `ERROR` | Anything that is not a solve outcome: a failed input load, a bad setting, an unexpected error. |

`OK` and `SUBOPTIMAL` are the two statuses whose results are complete and can be consumed. Output files may nonetheless exist for other statuses — a Myopic run writes each period as it goes, and a Benders solve with crossed bounds still writes its results — so the status, not the presence of a results directory, is what says whether the numbers can be used.

## [Configuration](@id manual-outputs-run-status-configuration)

Both settings are keyword arguments to [`run_case`](@ref). There are no run status settings in `macro_settings.json` or `case_settings.json`.

| Argument | Type | Default | Description |
|---|---|---|---|
| `write_status` | `Bool` | `true` | Write the run status file. |
| `status_file_path` | `AbstractString` | `<case_path>/run_status.json` | Path of the run status file to write. The copy in the results directory keeps the same file name. |

## [Assumptions](@id manual-outputs-run-status-assumptions)

- **`RUNNING` is written before the work starts.** A run killed by the operating system — a scheduler walltime, an out-of-memory kill — never reaches either the success or the failure path. The marker means such a run leaves `RUNNING` behind rather than the previous run's `OK`, which a watcher would otherwise read as success. A `RUNNING` status on a job that is no longer alive means it was killed.
- **Overwritten on each run.** The case-level file always reflects the most recent run. The copy in the results directory is what preserves the record of earlier runs, since each gets its own `results_00N/` directory when `OverwriteResults = false`.
- **Failures never reach the results directory.** The copy is only written on success, so a results directory with no `run_status.json` is one whose run did not finish. A Myopic run can leave such a directory behind, holding the periods that completed before the failure.
- **Never half-written.** The file is written to a temporary file in the same directory and renamed over the target, so a poller reads either the previous contents or the new ones, never a partial document.
- **The directory must already exist.** A `status_file_path` pointing into a directory that has not been created produces a warning, not a new directory: creating one would silently produce a case directory for a mistyped path.
- **Write failures are warnings, not errors.** If the file cannot be written — a read-only case directory, for instance — Macro warns and continues. The status file must never replace the exception it is reporting.

## [Examples](@id manual-outputs-run-status-examples)

### Read the status in Julia

```julia
using JSON3

status = JSON3.read(read(joinpath("my_case", "run_status.json"), String))
status.status == "INFEASIBLE" && @warn "Infeasible in $(status.label)"
```

### Catch the exception directly instead

If the caller is itself Julia, catch the exception rather than reading the file:

```julia
using MacroEnergy

try
    (case, solution) = run_case(@__DIR__)
catch e
    e isa InfeasibleModel && @warn "Infeasible: $(e.status) in $(e.label)"
    rethrow()
end
```

### Disable the status file

```julia
using MacroEnergy

run_case(@__DIR__; write_status=false)
```

## [See Also](@id manual-outputs-run-status-see-also)

- [`run_case`](@ref) — full list of keyword arguments
- [Log File](@ref "manual-outputs-log-file") — the human-readable record of the same run, which keeps the untruncated error message
- [Settings Output](@ref "manual-outputs-settings-output") — the `settings.json` file archived alongside it
