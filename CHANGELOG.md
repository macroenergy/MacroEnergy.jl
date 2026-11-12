# Changelog

All notable changes to MacroEnergy.jl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows Julia package versioning through `Project.toml` releases.

## [Unreleased]

### Added

- `MacroEnergy.migrate_settings(path; dry_run=true)` updates the settings of a case written for an earlier version: it moves the settings of `macro_settings.json` into `case_settings.json` under their current names, and removes the `settings` entries of the periods from `system_data.json`. By default it only reports the changes.
- Added a `commodities` object to location inputs for defining commodity nodes directly in `locations.json`, including demand, supply segments, time series, and node constraints. Empty objects use existing node defaults and generate `<location>_<commodity>` node IDs; explicit IDs override the default. Existing location-name strings and independent `nodes.json` definitions remain supported.
- Added `write_json(io::IO, data::AbstractDict)` for writing JSON to a caller-owned stream without closing it.

### Fixed

- A `DiscountRate` written as a whole number (`0` or `0.0`) no longer fails with a `MethodError` when loading a case.
- Loading a case no longer empties `system_data.json` when the file holds a value that could not be written back, such as `Infinity`.
- Time-domain reduction now keeps `settings/benders_settings.json` and files named inside `case_settings.json`. The reduced case used to fall back to default Benders settings without saying so.
- Paths in `settings` entries are now relative to `system_data.json`, as documented. The current directory was checked first, so a matching file there was read instead.
- Time-domain reduction now copies a single-period case's `settings/case_settings.json` into the reduced case when `system_data.json` does not reference it. The reduced case used to lose those settings silently and fall back to the defaults.
- A `case_settings.json` file without a `SolutionAlgorithm` key no longer fails with a `KeyError`.
- Added `edge_losses.csv` output file to report the commodity lost on every edge with a nonzero `loss_fraction`, for all solution algorithms and in the full time series (key `Losses` in `OutputSettings.Layout`, `OutputSettings.Format` and `OutputSettings.Write`). Lossy `BidirectionalEdge`s now hold their `flow_pos`/`flow_neg` pair as fields.
- Fixed `mermaid_diagram` to create explicit placeholder endpoints in its temporary system, preserving asset diagrams with stricter `AutoCreateNodes` endpoint validation. Commodity names also resolve consistently when called from another Julia module.
- Lossy bidirectional edges now split their flow into a single `vFLOWPOS`/`vFLOWNEG` pair shared by both vertex balances.
- Iterating over `SubproblemsData`, the container for per-subproblem Benders results, no longer yields the first subproblem twice. Written outputs were not affected, since the output writers read its fields directly rather than iterating it.
- Fixed TDR weights for shared CSV columns so excluded references and references with no matching feature do not increase clustering influence. Total usage counts are retained for provenance; clustering occurrence summaries count included references only.
- Corrected exported duals after MacroEnergyScaling constraint-row and objective scaling. All model builders now retain cumulative scaling metadata per model, and dual reporting restores the original model units before applying input scaling, time weights and discount conversions. Requires MacroEnergyScaling v0.4.1 or later.
- Multi-period cases no longer fail with a `MethodError` when carrying over capacities for an asset whose optional edge is absent, such as a `BECCSHydrogen` asset without a `fuel_edge`. Myopic runs with `ReturnModels: false` failed the same way when releasing such an asset.
- Myopic runs with `ReturnModels: false` now also release the JuMP references held by system-wide and per-location grouped capacity constraints. These kept an emptied model alive for each period, which increased memory use with the number of periods.
- Fixed location membership for automatically created nodes so location-based outputs and capacity constraints can identify their location correctly. Automatic nodes are registered before attachment, so rejected duplicate IDs leave membership unchanged and repeated lookups still fail.
- Fixed unresolved endpoint handling: `AutoCreateNodes` now reports an error when an endpoint matches neither an existing node nor a location, rather than attempting to create an anonymous node.
- Fixed time-domain reduction commodity context for nodes defined within locations, so commodity-scoped feature weights and exclusions apply to inline series and CSV references. Reference exclusions now match actual input context, including file, field, asset, and commodity, even when a generic feature is selected.
- Fixed `template_location` to support location dictionaries and mixed batches, preserve existing commodity and constraint definitions, and check duplicates by location ID. Conflicting definitions are rejected before writing; new JSON files and directories can be created directly.
- Fixed time-domain reduction of inputs defined inline within `case` entries in `system_data.json`. Bare and case-wrapped Systems now share scoped discovery and rewriting, so reduced and isolated subperiod cases use the selected periods' values without mixing Systems' profiles. Older output-feature caches are invalidated and regenerated.

### Changed

- Variable O&M cost on a `BidirectionalEdge` is now charged on |flow| via its `flow_pos`/`flow_neg` pair, instead of on the net flow; the `VariableOM` cost outputs follow the same rule.
- A negative `variable_om_cost` on a unidirectional edge (including edges with unit commitment) is now a credit per unit of flow in the objective and the `VariableOM` cost outputs, instead of being ignored. A negative `variable_om_cost` on a `BidirectionalEdge` is an error, since it is charged on |flow|.
- Automatically created commodity nodes now use `<location>_<commodity>` IDs instead of reusing the location ID.
- Location entries are normalized into a validated `LocationInput` with a required nonempty string ID and optional constraint and commodity dictionaries. Programmatic location dictionaries must use symbol keys, matching parsed JSON inputs; location-name strings remain supported.
- Location loading now creates each location and its declared nodes before loading independent nodes and assets. Node and location IDs share one namespace, with collisions rejected by both registration methods. Input validation also rejects duplicate commodity nodes within a location and conflicting location assignments as objects are loaded or registered.
- Multi-System TDR copies configured asset directories to `inputs/system_<n>/assets`, avoiding repeated source directory names such as `assets/assets_1` when the destination is free of other dependencies.
- All settings now live in one file, `settings/case_settings.json`, and apply to every period of the case. See "Migration guide" below.
- `case.settings` and the `settings` of every `System` in the case are now the same object, holding all the settings. `results/settings.json` holds them directly, instead of under `case_settings` and `system_settings`, in the same form as `case_settings.json`, so it can be copied to `settings/case_settings.json` to rerun a case with the same settings.
- Output settings are now grouped in an `OutputSettings` block of `case_settings.json`: `Dir`, `Overwrite`, `Format`, `Layout`, `Write`, `SignificantDigits` and `AssetTags`. `WriteFullTimeseries` is now `OutputSettings.Write.FullTimeseries`, off by default. Code that reads these settings should use `system.settings.OutputSettings`, or the accessors such as `output_enabled`. `system.settings.DualExportsEnabled` no longer exists.
- Output settings can no longer vary between periods. Every period of a multi-period case writes the same outputs.
- Settings are now strict. Unknown keys in `case_settings.json`, `BendersSettings` and `MyopicSettings` are errors, and so are unknown values of `SolutionAlgorithm` and `ExpansionHorizon`, which used to fall back to the default with a warning. Keys starting with `#` are treated as comments and ignored. `PeriodLengths` must be whole numbers, `ParameterScalingFactor` must be greater than zero, and `NaN` is rejected wherever a lower bound applies.
- A case with a `case` key and no top-level `settings` entry now reads `settings/case_settings.json`, as single-period cases do. On its own, `load_system` reads the same settings as `load_case`.
- A `settings/benders_settings.json` that overrides different settings written in `case_settings.json` now logs a warning. A `BendersSettings.path` pointing to a missing file is now an error, unless `settings/benders_settings.json` exists.
- Extended DuckDB.jl compatibility to include 2.x (`DuckDB = "1, 2"`). Environments that resolve DuckDB.jl 2.x read CSV inputs with the bundled DuckDB 2.0 engine.
- Settings are now defined and validated from a single declarative spec per file (`src/config/settings_schema.jl`, built on the new `InputField`/`InputMap`/`InputBlock` types in `src/load_inputs/input_schema/input_spec.jl`). Invalid settings now raise an `InputValidationError` that names the full key path and the expected value (e.g. `case_settings.BendersSettings.MaxIter: expected an integer > 0, got 0`) instead of a bare `AssertionError`. Defaults and accepted values are unchanged, except that settings which previously crashed later in the run are now rejected up front: non-boolean values for boolean settings, `true`/`false` for numeric settings, and a non-list `PeriodLengths`. A partial `MyopicSettings.Restart` block is now completed from its defaults instead of failing with a `KeyError`.

### Deprecated

- `macro_settings.json` and the `settings` entry of each period in `system_data.json`. Cases written this way still load, with a warning. It is an error if the periods have different settings, or if the settings contradict `case_settings.json`.
- The flat output setting names (`OutputDir`, `OverwriteResults`, `OutputFormat`, `OutputLayout`, `WriteOutputs`, `OutputSignificantDigits`, `OutputAssetTags`), `WriteFullTimeseries` and `DualExportsEnabled`. They are translated to `OutputSettings` with a warning. Setting an old name and its new name to different values is an error.

### Migration guide

- The "Updating older cases" section of the settings guide (Configuring Settings) walks through a full example, before and after, and lists where each setting goes.
- `MacroEnergy.migrate_settings("path/to/case")` shows the changes for a case, and `MacroEnergy.migrate_settings("path/to/case"; dry_run=false)` makes them.
- Move the contents of `macro_settings.json` into `settings/case_settings.json` and delete the `settings` entry of each period in `system_data.json`.
- Rename the output settings: `OutputDir` to `OutputSettings.Dir`, `OverwriteResults` to `OutputSettings.Overwrite`, `OutputFormat` to `OutputSettings.Format`, `OutputLayout` to `OutputSettings.Layout`, `WriteOutputs` to `OutputSettings.Write`, `WriteFullTimeseries` to `OutputSettings.Write.FullTimeseries`, `OutputSignificantDigits` to `OutputSettings.SignificantDigits`, `OutputAssetTags` to `OutputSettings.AssetTags` and `DualExportsEnabled` to `OutputSettings.Write.Duals`.
- In Julia code, read these settings from `system.settings.OutputSettings` (e.g., `system.settings.OutputSettings.Dir` instead of `system.settings.OutputDir`). Reading an old name raises an error, and so does building a model or reading output settings after setting an old name on `system.settings`.

### Documentation

- Synced the tutorials with MacroEnergyExamples.jl: added Tutorial 3 (a three-zone multisector showcase) and a Benders decomposition section in Tutorial 1, and updated the code in Tutorials 0-2 to the current API (`scaling` argument of the result functions, `resource_type` output column, sign of storage charge flows).
- Fixed the Tutorial 2 asset diagrams, which did not load on the deployed site, and a table-of-contents entry pointing to a tutorial page that does not exist.

## [0.3.0 - rc] - 2026-10-14

### Added

- Added `@add_to_balance` for appending raw terms to an existing named balance.
- Added `@add_to_storage_balance` as the preferred helper for extending storage law-of-motion balances.
- Added `@inspect_stoichiometric_balance` to inspect the pairwise equations generated by `@add_stoichiometric_balance`.
- Added focused single-asset solve tests under `test/asset_tests` to validate migrated asset balances against manual algebraic rewrites where appropriate.
- Added scaling functionality for input data. New `ParameterScaling` (default `false`) and `ParameterScalingFactor` (default `1e3`) parameters have been added to case settings.
- Added capacity_summary.csv for multi-period cases, combining per-period capacity outputs into a single long- or wide-format file.
- Added optional StartYear input in case_settings.json to label periods by calendar year.
- Added `capex.csv` output file to report per-component asset capital costs.
- Added repository-local benchmarking tools to compare case loading, case generation, and model generation between `upstream/main` and the current worktree using reproducible example inputs.
- Added system-wide and per-location capacity constraints for selected groups of assets: `MaxCapacityConstraint` and `MinCapacityConstraint` bound total capacity, and `MaxNewCapacityConstraint` bounds newly built capacity. Limits are configured via a `constraints` block in `system_data.json` (whole system) or per location in `locations.json`, using asset-type and tag selectors. The limit values are scaled with `ParameterScaling` like other capacity inputs.
- For `VRE`, the optional `technology` input is normalized into an asset tag (for example, `technology: "Solar"` adds `:solar`) without changing the asset's Julia type.
- Added `ConstrainedFossilLiquidFuels`, a refinery asset with fixed jet-fuel and diesel output ratios and configurable fuel-specific emissions.
- Added optional auxiliary-fuel inputs to `BECCSHydrogen` and captured-CO₂ return flows to `SyntheticLiquidFuels`.
- Added unit-commitment support for `Electrolyzer` hydrogen output, including startup electricity consumption, minimum up/down times, and ramping limits.
- Added time-domain reduction (TDR) to replace full input time series with weighted representative periods. The new `preprocess_inputs` and `time_domain_reduction` workflows generate a separate reduced case that loads and runs through the ordinary MacroEnergy APIs.
- Added JSON-configured TDR with independent per-System settings, k-means, k-medoids and autoencoder clustering, feature selection and weights, scaling, and forced extreme-period selection.
- Added TDR input discovery for JSON and model-input CSV references across arbitrary directories, including inline time-series vectors. Per-System copies retain only required files and time-series columns, preserve model-input CSV format, and consolidate identical shared inputs.
- Added optional model-output clustering features from isolated candidate-period solves, with distributed execution, selective policy-constraint exclusion, retained inputs/results, and fingerprint-validated feature caches under the source case’s `TDR/` directory.
- Added support for reclustering into shorter representative periods while preserving source-period boundaries and occurrence weights. TDR reports trimmed timesteps, rejects longer requested periods, updates time settings, and validates source/destination separation before overwriting.
- Added TDR period maps, provenance and feature-use logs, including records of inputs reduced without being used for clustering. Preprocessing logs are saved under `preprocessing_logs/` in the reduced case.
- Added `OutputFormat` setting in `macro_settings.json` to write output tables as `"csv"` (default), `"csv.gz"` or `"parquet"`, globally or per output (e.g., `{"Flow": "parquet"}`). Compressed formats make results folders much smaller; on an 8-period test case, Parquet output was 26× smaller than CSV.
- Added `WriteOutputs` setting in `macro_settings.json` to skip individual output files (e.g., `{"Curtailment": false, "Duals": false}`). Outputs that are not listed are still written.
- Added `OutputSignificantDigits` setting in `macro_settings.json` to round time-series outputs (flows, storage levels, curtailment, non-served demand, balance duals) to a number of significant digits before writing. Capacity, cost and CAPEX outputs keep full precision.

### Changed

- Parquet outputs are now zstd-compressed (about 3× smaller than the previous snappy default), and Symbol columns with missing values are written correctly.
- Myopic restarts now read `capacity.csv`, `capacity.csv.gz` or `capacity.parquet` from the restart folder, whichever was written. If none exists, the error says which file is missing and suggests the likely cause (`WriteOutputs.Capacity = false`). If more than one exists (left over from an earlier run with `OverwriteResults = true`), the restart stops with an error instead of picking one.
- A Myopic run that stops early (`StopAfterPeriod`) now fails before the first solve if `WriteOutputs.Capacity` is `false` for any period it writes, since a later restart needs those files. A run to the last period only logs a warning.
- Cached repeated reads of shared CSV inputs within each case or system load, avoiding repeated full-file parsing when assets select different columns from the same file.
- `@add_balance` is now the recommended API for ordinary algebraic balance equations and inequalities, and follows standard algebraic sign conventions for `flow(...)` terms.
- `@add_balance` now validates balance expressions more strictly and rejects unsupported non-`flow(...)` variable terms.
- `@add_stoichiometric_balance` now expands recipe-style balances using a consistent proportional rule around the selected `base_term`.
- Asset balance definitions have been migrated away from legacy raw `balance_data = Dict(...)` patterns toward `@add_balance`, `@add_to_storage_balance`, and `@add_stoichiometric_balance`.
- Updated MacroEnergyScaling.jl compatibility to 0.4. Constraint scaling now updates constraints in place, so existing JuMP `ConstraintRef`s remain valid instead of being invalidated by constraint replacement. This version also allows for objective scaling in the future.
- Hoisted repeated time-data lookups during model construction and simplified ramping and minimum up/down-time constraints to avoid temporary expression and index containers.
- Weight policy slack to ensure CO2 slack penalty has economic interpretation.
- A constraint entry in a `constraints` block may now be an inline configuration object (carrying its settings) instead of only the boolean `true`/`false` toggle, enabling data-driven constraint parameterization.
- Location entries in `locations.json` may now be objects carrying a `constraints` block (bare id strings still work), allowing location-specific constraints to be loaded from input data.
- Reduced model-generation allocations in edge balance updates by inserting flow variables directly into vertex balance expressions instead of constructing temporary effective-flow expressions.
- `run_case` now scopes logging to the run, restores the caller’s logger, and closes its own file log stream on success or failure.
- Storage Charge/Discharge limit constraints now can be applied to `LongDurationStorage`.

### Deprecated

- `DualExportsEnabled` in `macro_settings.json` is deprecated in favor of `WriteOutputs.Duals`. It still works: it is translated to `WriteOutputs.Duals` with a deprecation warning. Setting both to different values is an error. Code that reads `system.settings.DualExportsEnabled` keeps working: it is still `true` or `false`, mirroring `WriteOutputs.Duals`.

### Removed

- Removed `Revise` and `Test` from the package dependencies. `MacroEnergy.jl` no longer loads `Revise` at package load time, so developers who relied on that must now load it themselves; `Test` remains available to the test suite through `[extras]`/`[targets]`.

### Fixed

- Myopic runs with `MyopicSettings.ReturnModels = false` now actually free each period's model. Each period's references are now released once its results have been written, and the model is emptied. Results are unchanged; scalar capacities remain readable on the returned `Case` as `Float64`.
- Fixed asset component traversal and Benders planning updates for assets whose optional edges are absent.
- `StorageChargeLimitConstraint` is now attached to a `Battery`'s charge edge. Before, it was declared as a top-level key in the charge edge's default data instead of inside its `constraints` dictionary, so it was silently dropped.
- Dual exports now handle unavailable solver duals safely, recording `NaN` instead of failing while preserving `Float64` output arrays.
- CSV input reading now releases file handles deterministically to allow immediate rewriting and deletion on Windows. JSON reads/writes and CSV header reads also close streams after exceptions.

### Documentation

- Expanded the balance documentation with guidance on choosing between balance macros, stoichiometric coefficient bases, pairwise expansion limits, multi-term algebraic balances, common mistakes, and numerical sensitivity.
- Updated modeler documentation to include balance APIs in the asset-construction workflow and to recommend a small single-asset regression test for each new asset.
- Updated debugging guidance around `balance_data`, `get_balance`, and `@inspect_stoichiometric_balance`.
- Updated asset-specific documentation examples to use the balance macros instead of legacy raw balance dictionaries.
- Added preprocessing and TDR manuals covering configuration, input discovery, candidate construction, clustering, output-feature caching, generated files, and function workflow trees.
- Added output manual sections on output formats and file sizes, selecting outputs, and reading all periods' outputs as one table with DuckDB, polars or pandas.

### Migration guide

- When updating an asset, prefer `@add_balance` for ordinary algebraic equalities and inequalities, prefer `@add_to_storage_balance` for storage law-of-motion terms, and use `@add_stoichiometric_balance` only when the relationship is naturally a recipe-style proportional conversion.
- Legacy raw balance dictionaries should usually be replaced with explicit balance macros. For example:

```julia
transform.balance_data = Dict(
    :energy => Dict(
        output_edge.id => coeff,
        input_edge.id => 1.0,
    ),
)
```

can become:

```julia
@add_balance(transform, :energy, flow(output_edge) == coeff * flow(input_edge))
```

or, when the relationship is best represented as a recipe:

```julia
@add_stoichiometric_balance(
    transform,
    :production,
    coeff * flow(input_edge) --> flow(output_edge),
    flow(output_edge),
)
```

- Use `@add_balance` when the relationship is easiest to write as an explicit equation, includes three or more independently varying terms, or is not just a set of pairwise proportional relations.
- Use `@add_stoichiometric_balance` when one `base_term` should anchor several proportional relationships and all coefficients can be written on a common recipe basis.
- In one `@add_stoichiometric_balance` expression, all coefficients must share a common basis. For example, if the base term is product output, coefficients should usually be expressed per unit output; if the base term is fuel input, coefficients should usually be expressed per unit fuel.
- When extending the `:storage` balance of a storage component, use `@add_to_storage_balance(storage, coeff * flow(edge))`. In normal usage, write positive magnitudes for both inflows and outflows and let MacroEnergy apply the effective sign through edge direction.
- During migration, inspect generated pairwise equations with `@inspect_stoichiometric_balance(...)`, inspect stored coefficients with `balance_data(component, balance_id)`, inspect compiled expressions with `get_balance(component, balance_id)`, and validate the asset with a small single-asset solve test.
- Small differences in large-system results do not automatically indicate a balance bug. Algebraically equivalent formulations can change row scaling and solver tie-breaking in large, near-degenerate systems, so localized single-asset regression tests are the primary evidence that migrated balances remain correct.
- **Results change:** no public API changed, but any case using a `Battery` asset could now produce different results. The charge limit (`charge_flow[t] <= capacity - storage_level[t-1]`, scaled by the charge efficiency) was previously not included by default and is now enforced. To keep the old behavior, disable it explicitly on the charge edge: `"charge_edge": {"constraints": {"StorageChargeLimitConstraint": false}}`.
- If you set `StorageChargeLimitConstraint` as a top-level key on a charge edge, rather than inside that edge's `constraints` dictionary, it was and still is ignored. Move it inside `constraints` for it to take effect.
- Replace `"DualExportsEnabled": false` in `macro_settings.json` with `"WriteOutputs": {"Duals": false}`. `"DualExportsEnabled": true` can simply be removed, since duals are written by default.
- `StorageChargeLimitConstraint` only applies to an edge whose end vertex is the storage, i.e. the charge edge. Setting it on the discharge edge (or via `discharge_constraints` in the simple input format) has no effect.

## [0.2.4] - 2026-09-10

### Changed

- Skip Julia CI tests when changes are confined to `CHANGELOG.md`, `README.md`, or `docs/`, while retaining documentation builds and a consistent `CI result` check that reports successful tests or an intentional skip.

### Fixed

- Removed `[skip ci]` from automated changelog commit messages so release tags pointing to those commits can trigger documentation deployment.

## [0.2.3] - 2026-08-31

### Documentation

- Switched documentation math rendering to MathJax3 and pinned Mermaid to 11.16.1 to avoid Mermaid 11.17's RequireJS compatibility regression.

## [0.2.2] - 2026-08-05

### Fixed

- Duplicate asset IDs within a system are now rejected during system generation, preventing ambiguous myopic capacity carry-over and late wide-output failures.

## [0.2.1] - 2026-07-15

### Changed

- Updated MacroEnergySolvers.jl version to 0.2.2

### Fixed

- Fix wacc default preventing fallback to DiscountRate. Omitted `wacc` was silently treated as `0.0` instead of falling back to the case-level `DiscountRate`.

### Migration guide

- **Results change:** no public API changed, but any case that omits an asset's `wacc` will now produce different results. Previously the missing `wacc` defaulted to `0.0`; it now falls back to the case's `DiscountRate`. Cases relying on the old default will see different annualized investment costs after upgrading. To keep the old behavior, set `wacc` explicitly to `0.0` for the affected asset(s).

## [0.2.0] - 2026-05-22

### Added

- Outputs can now be written to a JSON file using the `write_to_json` method. This method writes to a compressed `.json.gz` but also supports regular `.json` outputs. It is not currently built into any of the run tools.
- Improved JSON serialization coverage of commodities, storage, constraints, dual values, time data, solution algorithms, named tuples, JuMP containers, and special numeric values like Inf, -Inf, and NaN

### Changed

- CSV asset input files can now have their `Type` and `Id` columns in any position in the file, instead of needing to be in the first two columns. The `Type` and `Id` columns are still required.
- `run_case` now returns `(case, solution)` as opposed to `(systems, solution)`. The `case` object contains the `systems` as well as `case`-level settings.

### Migration guide

- If you are using the `run_case` function, update your code to handle the new return signature of `(case, solution)` instead of `(systems, solution)`.

For example, if you previously had:

```julia
(system, solution) = run_case(@__DIR__; 
    optimizer=HiGHS.Optimizer,
    optimizer_attributes=("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
);
```

You should now use:

```julia
(case, solution) = run_case(@__DIR__;
    optimizer=HiGHS.Optimizer,
    optimizer_attributes=("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
);
```

If you need to access the systems, you can retrieve them from the `case` object.

```julia
systems = case.systems
```

## [0.1.0] - 2026-04-14

### Added

- Expanded result writing and postprocessing for non-served demand, storage level, curtailment, time weights, discounted and undiscounted cost outputs, and detailed cost breakdowns.
- Added full time-series reconstruction across Monolithic, Myopic, and Benders workflows through `WriteFullTimeseries`.
- Added `SyntheticAmmonia`, `SyntheticMethanol`, `ThermalAmmonia`, `ThermalAmmoniaCCS`, `ThermalMethanol`, `ThermalMethanolCCS`, and `OneWayTransmissionLink` assets.
- Added `StorageChargeLimitConstraint`, long-duration storage feasibility constraints for Benders, and additional storage safety checks.
- Added Myopic restart support, `StopAfterPeriod`, optional JuMP direct-model generation, optional string names, updated default HiGHS settings, and economic utilities for present-value and cash-flow calculations.

### Changed

- Redesigned node supply inputs around named supply dictionaries with per-segment `price`, `min`, and `max` values.
- Split edge types into explicit unidirectional and bidirectional forms.
- Changed `TransmissionLink` to model bidirectional transfer; use `OneWayTransmissionLink` for one-way transfer.
- Cleaned up user extension loading through the `user_additions/` layout.
- Renamed emissions-tracking assets to `UpstreamEmissions` and `DownstreamEmissions`, with compatibility aliases for older names.
- Expanded documentation and tests for TimeData, timeseries outputs, retrofitting, run workflows, outputs, constraints, assets, transmission links, supply parsing, and user additions.

### Removed

- Removed legacy unified output code in favor of the expanded `write_*` output suite.

### Fixed

- Improved Benders output parity and cost handling by performing a final operational solve for the selected planning solution.
- Fixed and improved transmission, storage, dual, cost, and documentation behavior across the release.

### Migration guide

- Update node supply inputs to the named `supply` dictionary format. Each supply segment should define `price`, `min`, and `max` values. Legacy `price_supply` and `max_supply` inputs are still handled, and `update_node_supply_inputs(...)` can help convert existing cases.
- Review any cases using automatically generated supply segment names. Segment names now use `segment1`, `segment2`, and so on.
- Review transmission assets. `TransmissionLink` is now bidirectional by default; use `OneWayTransmissionLink` when directionality matters.
- Update any direct use of edge types to the explicit unidirectional and bidirectional edge forms.
- Update output-processing scripts that relied on the legacy unified output code. Use the expanded `write_*` output functions instead.
- Review models that assumed nodes did not include balance constraints by default. Nodes now have `BalanceConstraint` enabled by default.
- Prefer the renamed emissions assets `UpstreamEmissions` and `DownstreamEmissions`. Compatibility aliases remain for older names, including `FossilFuelsUpstream` and `FuelsEndUse`.

## [0.0.3] - 2025-11-21

### Added

- Added iron and steel sector assets and documentation.
- Added heat and steam sector commodities, assets, examples, and documentation.
- Added aluminum sector default real-world parameters.
- Added output support for dual values from `BalanceConstraint` and `CO2CapConstraint`.
- Added minimum retired capacity tracking and extended retrofit features to multi-stage models.
- Added Windows coverage to CI.

### Changed

- Updated installation instructions, citation metadata, asset library docs, modeler debugging docs, and timeseries documentation.

### Fixed

- Fixed several Windows-related path and user-additions issues.
- Fixed retrofit integer decisions, hydropower reservoir efficiency handling, documentation cross references, and Benders dual scaling behavior.

## [0.0.2] - 2025-09-25

### Added

- Added logging options.
- Added settings output in results.
- Added automatic Mermaid diagrams for assets.
- Added asset retrofits for single-stage cases.
- Added options to free model memory and write myopic outputs during iterations.

### Changed

- Refactored output-writing utilities.

### Fixed

- Fixed subcommodity loading.

## [0.0.1] - 2025-08-20

### Added

- Initial registered release of MacroEnergy.jl.

[Unreleased]: https://github.com/macroenergy/MacroEnergy.jl/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/macroenergy/MacroEnergy.jl/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/macroenergy/MacroEnergy.jl/compare/v0.0.3...v0.1.0
[0.0.3]: https://github.com/macroenergy/MacroEnergy.jl/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/macroenergy/MacroEnergy.jl/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/macroenergy/MacroEnergy.jl/releases/tag/v0.0.1
