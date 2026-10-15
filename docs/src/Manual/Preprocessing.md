# Preprocessing Inputs

Preprocessing transforms a source case into a new, ordinary MacroEnergy case
directory before it is loaded or solved. It is intended for input-only changes
that should be explicit, reproducible, and independent of `run_case`.

Each preprocessing workflow copies the source case, applies its transformations
to that copy, and writes `preprocessing_logs/preprocess_log.json` describing what changed. The
source model inputs are not modified. Saved output-feature caches and retained
subperiod artifacts are written under the source case’s `TDR/` directory.

The currently available workflow is:

- [Time-Domain Reduction](@ref "Time-Domain Reduction")

Additional input preprocessing workflows will be documented here as they are
added.

## Preprocessing workflow

The current workflow is shown below. Function calls have parentheses; bracketed
notes explain a step's purpose and can name the function used. `FOR EACH` marks
iteration. TDR is the only preprocessing
transformation currently implemented; future transformations can be added to
this overview as they become available.

```text
preprocess_inputs(source_root, output_root; tdr_settings_path, ...)
├─ [Read settings and prepare validated input data before copying]
│  ├─ [Find number of systems using tdr_system_entries(source_root)]
│  ├─ load_tdr_settings_by_system(tdr_settings_path, number_of_systems)
│  └─ tdr_prepare_inputs(source_root, settings_by_system; definition)
│     └─ [Build candidate plans and discover sources and dependencies once per System]
├─ copy_case(source_root, output_root; prepared, settings_path, ...)
│  └─ [Check paths and overwrite; copy inputs, supporting files and in-source TDR settings]
├─ tdr_prepare_system_inputs!(output_root, prepared)
│  └─ [For multiple Systems, copy relevant dependencies and time-series columns into private trees]
└─ tdr_time_domain_reduction(output_root, settings_by_system, working_inputs; ...)
   └─ [Reduce each System; write time settings, period maps, provenance and log]

[After preprocessing, run the generated Case separately]
run_case(output_root; ...)
```

Both `preprocess_inputs(...)` and the direct `time_domain_reduction(...)` entry
point validate and prepare data before any input mutation. Internal helpers reuse
that prepared data.

For the detailed TDR and optional output-feature solve trees, see
[Function workflow](Preprocessing/TimeDomainReduction.md#function-workflow).
The final reduced model is run separately. Output-based TDR can additionally
perform isolated candidate-period solves while preprocessing.

## API

```@docs
MacroEnergy.preprocess_inputs
MacroEnergy.tdr_case_location
```
