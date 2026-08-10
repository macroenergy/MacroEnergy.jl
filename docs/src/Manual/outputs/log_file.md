# [Log File](@id manual-outputs-log-file)

## Contents

[Overview](@ref "manual-outputs-log-overview") | [Location](@ref "manual-outputs-log-location") | [Format](@ref "manual-outputs-log-format") | [Configuration](@ref "manual-outputs-log-configuration") | [Assumptions](@ref "manual-outputs-log-assumptions") | [Examples](@ref "manual-outputs-log-examples") | [See Also](@ref "manual-outputs-log-see-also")

## [Overview](@id manual-outputs-log-overview)

**File:** `<case_name>.log`

Macro writes a log file capturing all messages emitted during a model run — loading inputs, building the optimization model, solving, and writing outputs. The log is a plain-text file with one message per line, each prefixed with a timestamp and (optionally) source attribution.

The log file is the primary tool for diagnosing slow runs, debugging unexpected behavior, and auditing what happened during a solve.

## [Location](@id manual-outputs-log-location)

The log file is written in two places:

1. **During the run:** at `<case_path>/<case_name>.log` (in the case directory itself), so it is available immediately while the solve is in progress.
2. **After the run:** copied into the **outer results directory** (e.g., `results_001/<case_name>.log`) alongside `settings.json`, so the log is archived with the results.

```
my_case/
├── my_case.log               ← written here during the run
└── results_001/
    ├── my_case.log           ← copied here after the run completes
    ├── settings.json
    └── results/
        ├── capacity.csv
        └── ...
```

The default log file path is `joinpath(case_path, "$(basename(case_path)).log")`. For a case at `/path/to/my_case/`, this produces `/path/to/my_case/my_case.log`.

## [Format](@id manual-outputs-log-format)

Macro supports two log file formats, selected via the `log_file_attribution` argument to [`run_case`](@ref).

### Attributed Format (default)

When `log_file_attribution = true` (the default), each line contains:

```
timestamp | LEVEL | worker_id | Module | file:line | message
```

| Field | Description |
|---|---|
| `timestamp` | Wall-clock time in `yyyy-mm-dd HH:MM:SS` format |
| `LEVEL` | Log level: `INFO`, `WARN`, `ERROR`, or `DEBUG` |
| `worker_id` | Julia process ID (1 for the main process; >1 for distributed workers in Benders runs) |
| `Module` | Julia module that emitted the message |
| `file:line` | Source file and line number within that module |
| `message` | The log message text |

Example lines:

```
2026-03-15 09:12:04 | INFO | 1 | MacroEnergy | run_tools.jl:128 | Running case at /path/to/my_case
2026-03-15 09:12:05 | INFO | 1 | MacroEnergy | load_inputs.jl:44 | Loading case inputs...
2026-03-15 09:12:11 | INFO | 1 | MacroEnergy | generate_model.jl:30 | Generating model...
2026-03-15 09:14:02 | INFO | 1 | MacroEnergy | solver.jl:18 | Solving model...
2026-03-15 09:16:45 | INFO | 1 | MacroEnergy | write_outputs/utilities/output_utilities.jl:89 | Writing outputs to results_001/results
```

### Concise Format

When `log_file_attribution = false`, each line contains only the timestamp and message:

```
timestamp | message
```

Example:

```
2026-03-15 09:12:04 | Running case at /path/to/my_case
2026-03-15 09:12:05 | Loading case inputs...
2026-03-15 09:14:02 | Solving model...
```

## [Configuration](@id manual-outputs-log-configuration)

All log settings are passed as keyword arguments to [`run_case`](@ref). There are no log-related settings in `macro_settings.json` or `case_settings.json`.

| Argument | Type | Default | Description |
|---|---|---|---|
| `log_to_file` | `Bool` | `true` | Write log messages to a file. |
| `log_to_console` | `Bool` | `true` | Print log messages to the console (stdout). |
| `log_level` | `LogLevel` | `Logging.Info` | Minimum severity to record. Messages below this level are suppressed. |
| `log_file_path` | `AbstractString` | `<case_path>/<case_name>.log` | Path of the log file to write. |
| `log_file_attribution` | `Bool` | `true` | Include source-level attribution (module, file, line) in each log line. |

### Log Levels

Log levels follow Julia's standard `Logging` module hierarchy:

| Level | Constant | Description |
|---|---|---|
| Debug | `Logging.Debug` | Verbose diagnostic messages. Includes detailed progress within each loading and model-building step. |
| Info | `Logging.Info` | High-level progress messages (default). Reports major stages: loading, generating, solving, writing. |
| Warn | `Logging.Warn` | Warnings only — potential issues that do not stop execution (e.g., missing optional files). |
| Error | `Logging.Error` | Errors only. Rarely produces output before an exception is thrown. |

!!! note "Importing Logging"
    To change the log level, you must import Julia's `Logging` standard library:
    ```julia
    using Logging
    run_case(@__DIR__; log_level=Logging.Debug)
    ```

## [Assumptions](@id manual-outputs-log-assumptions)

- **Written at the case root, not in the results directory.** The log file is written to the case directory during the run. It is only copied into the results directory after the solve completes successfully. If the run errors before completion, the log file will exist at the case root but will **not** be copied to the results directory.
- **Overwritten on each run.** The log file at the case root is always overwritten (`append = false`) at the start of each run. The copy in the results directory is also overwritten if `OverwriteResults = true`, or a new copy is placed in the new `results_001/`, `results_002/`, etc. directory if `OverwriteResults = false`.
- **Both console and file can be active simultaneously.** When both `log_to_console = true` and `log_to_file = true`, Macro uses a `TeeLogger` that writes to both destinations. The formats differ: the file uses the attributed or concise format; the console uses Julia's `ConsoleLogger` (with color if the terminal supports it) with a timestamp prepended in the message text via a `TransformerLogger`.
- **`log_to_file = false` disables the copy.** If `log_to_file = false`, no log file is created and nothing is copied to the results directory.

## [Examples](@id manual-outputs-log-examples)

### Disable file logging (console only)

```julia
using MacroEnergy

run_case(@__DIR__; log_to_file=false)
```

### Suppress console output (file only)

```julia
using MacroEnergy

run_case(@__DIR__; log_to_console=false)
```

### Enable debug-level logging

```julia
using MacroEnergy
using Logging

run_case(@__DIR__; log_level=Logging.Debug)
```

### Write log to a custom path

```julia
using MacroEnergy

run_case(@__DIR__; log_file_path="/path/to/logs/my_run.log")
```

### Use concise format (no source attribution)

```julia
using MacroEnergy

run_case(@__DIR__; log_file_attribution=false)
```

### Silence all output

```julia
using MacroEnergy

run_case(@__DIR__; log_to_console=false, log_to_file=false)
```

### Reading the log file in Julia

```julia
# Read the log from the results directory
log_path = joinpath("my_case", "results_001", "my_case.log")
log_lines = readlines(log_path)

# Filter to warnings and errors only
issues = filter(l -> occursin("| WARN |", l) || occursin("| ERROR |", l), log_lines)
foreach(println, issues)
```

### Grep for specific stages (on a Unix terminal, i.e., outside of a Julia REPL)

```bash
# Show only solver-related lines
grep "solver" my_case/results_001/my_case.log

# Show lines from worker 2 (Benders subproblem)
grep "| 2 |" my_case/results_001/my_case.log

# Show all lines from a specific source file
grep "generate_model" my_case/results_001/my_case.log
```

## [See Also](@id manual-outputs-log-see-also)

- [`run_case`](@ref) — full list of keyword arguments including all logging options
- `set_logger` — lower-level function for configuring the global logger directly
- [Settings Output](@ref "manual-outputs-settings-output") — the `settings.json` file archived alongside the log
