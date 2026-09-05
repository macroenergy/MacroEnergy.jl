# Preprocessing Inputs

Preprocessing transforms a source case into a new, ordinary MacroEnergy case
directory before it is loaded or solved. It is intended for input-only changes
that should be explicit, reproducible, and independent of `run_case`.

Each preprocessing workflow copies the source case, applies its transformations
to that copy, and writes a `preprocess_log.json` describing what changed. The
source case is not modified.

The currently available workflow is:

- [Time-Domain Reduction](@ref "Time-Domain Reduction")

Additional input preprocessing workflows will be documented here as they are
added.

## API

```@docs
MacroEnergy.preprocess_inputs
```
