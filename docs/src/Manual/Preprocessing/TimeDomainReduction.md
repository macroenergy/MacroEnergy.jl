# Time-Domain Reduction

`preprocess_inputs` creates a new, ordinary MacroEnergy case directory from an existing case. The generated directory loads with `load_case` and runs with `run_case` without TDR-specific run settings. Source model inputs are unchanged. Saved output-feature caches and retained subperiod artifacts are written under the source case’s `TDR/` directory.

```julia
preprocess_inputs(
    "path/to/full_case",
    "path/to/reduced_case";
    tdr_settings_path="path/to/tdr_settings.json",
)

case, solution = run_case("path/to/reduced_case")
```

The output directory must not already exist unless `overwrite=true` is passed. By default, top-level source directories whose names start with `results` are not copied; pass `copy_result_files=true` to retain them.

## Time-domain reduction settings

TDR settings are JSON. This example creates twelve representative weeks.

```json
{
  "timesteps_per_representative_period": 168,
  "representative_periods": 12,
  "method": {
    "name": "kmeans",
    "settings": { "restarts": 10 }
  },
  "scaling": "standardize",
  "features": [],
  "exclude": [],
  "extreme_periods": []
}
```

`timesteps_per_representative_period` and `representative_periods` must be positive integers. `scaling` is either `"standardize"` or `"normalize"`.

For multi-System Cases, one configuration is applied to every System by default. Set `representative_periods` to an array with one entry per System to vary only that count, or use a top-level `systems` array of complete TDR settings objects to configure every System independently. The entries follow the order in `system_data.json`.

### Multi-System settings examples

The ordinary scalar form applies the same settings to each System in a multi-System Case.

```json
{
  "timesteps_per_representative_period": 168,
  "representative_periods": 12,
  "method": { "name": "kmeans" },
  "scaling": "standardize"
}
```

To vary only the number of representative periods, provide one count per System. This three-entry configuration applies `8`, `12`, and `16` representative weeks respectively.

```json
{
  "timesteps_per_representative_period": 168,
  "representative_periods": [8, 12, 16],
  "method": { "name": "kmeans" },
  "scaling": "standardize"
}
```

For fully independent configurations, use `systems`. Each entry is a complete ordinary TDR settings object; the number and order of entries must match the Systems in `system_data.json`.

```json
{
  "systems": [
    {
      "timesteps_per_representative_period": 168,
      "representative_periods": 8,
      "method": { "name": "kmeans", "settings": { "restarts": 3 } },
      "scaling": "standardize"
    },
    {
      "timesteps_per_representative_period": 24,
      "representative_periods": 20,
      "method": { "name": "kmedoids", "settings": { "restarts": 5 } },
      "scaling": "normalize",
      "features": [
        { "field": "demand", "commodity": "Electricity", "weight": 2.0 }
      ]
    }
  ]
}
```

| JSON setting | Description | JSON type | MacroEnergy type | Default |
| --- | --- | --- | --- | --- |
| `timesteps_per_representative_period` | Timesteps in each candidate and representative period. | Integer | `Int` | Required |
| `representative_periods` | Retained-period count, or one count per System in a multi-System Case. | Integer or integer array | `Int` per resolved System | Required |
| `systems` | Complete per-System TDR configurations. Mutually exclusive with other top-level settings. | Array of objects | `Vector{TDRSettings}` | Not supplied |
| `method` | Clustering-method name and settings. | Object | `AbstractTDRMethodSettings` subtype | Required |
| `scaling` | Per-series scaling before clustering. | String: `"standardize"` or `"normalize"` | `Symbol` | Required |
| `features` | Input-feature additions or overrides. | Array of objects | `Vector{TDRFeatureSpec}` | `[]` |
| `exclude` | Feature selectors removed from clustering. | Array of objects | `Vector{TDRFeatureSpec}` | `[]` |
| `extreme_periods` | Feature-based representative periods selected before regular clustering. | Array of objects | `Vector{TDRExtremePeriodSpec}` | `[]` |
| `output_based_features` | Optional model-output clustering features. | Object or `null` | `Union{Nothing, TDROutputFeaturesSettings}` | `null` |

### Scaling

TDR scales each physical time series independently before stacking its period
profiles into the clustering matrix. Choose one of the following required
`scaling` values:

- `"standardize"`: z-score scaling, `(x - μ) / σ`, where `μ` is the series
  mean and `σ = sqrt(sum((x - μ)^2) / n)` is its population standard deviation.
- `"normalize"`: min--max scaling, `(x - minimum(x)) / (maximum(x) - minimum(x))`,
  producing values from zero to one.

A constant series becomes all zeros under either option, so it does not add
artificial variation to the clustering distance.

### Clustering methods

| `method.name` | Description |
| --- | --- |
| `"kmeans"` | Clusters input profiles and chooses the real period nearest each centroid. |
| `"kmedoids"` | Clusters using pairwise distances and selects medoid periods. |
| `"autoencoder_sequential"` | Trains an autoencoder, then runs k-means in its latent space. |
| `"autoencoder_simultaneous"` | Trains an autoencoder with reconstruction and clustering-aware loss, then runs k-means in its latent space. |

`method.settings` contains only settings supplied by the user; omitted values come from the selected method's validating constructor.

| JSON setting | Available methods | Description | JSON type | MacroEnergy field type | Default |
| --- | --- | --- | --- | --- | --- |
| `restarts` | All | Additional clustering restarts. | Integer | `Int` | `0` |
| `verbose` | All | Enable verbose output from the clustering method. | Boolean | `Bool` | `false` |
| `kernel_size` | Autoencoders | Convolution kernel width. | Integer | `Int` | `3` |
| `stride` | Autoencoders | Convolution stride. | Integer | `Int` | `1` |
| `epochs` | Autoencoders | Maximum training epochs. | Integer | `Int` | `50` |
| `min_err_diff` | Autoencoders | Minimum improvement used by early stopping. | Number | `Float64` | `0.0001` |
| `patience` | Autoencoders | Consecutive non-improving epochs before stopping. | Integer | `Int` | `10` |
| `warmup` | Autoencoders | Initial epochs before applying early stopping. | Integer | `Int` | `5` |
| `n_filters` | Autoencoders | Number of convolution filters. | Integer | `Int` | `8` |
| `latent_dim` | Autoencoders | Latent-space dimension. | Integer | `Int` | `4` |
| `lambda` | `"autoencoder_simultaneous"` | Clustering-loss weight. | Number | `Float64` | `0.1` |

Training occurs during preprocessing and does not write latent-space cache files into the case directory.

## Clustering features

The default feature fields are `availability`, `demand`, `supply.price`, `supply.min`, `supply.max`, and `loss_fraction`. For example, `supply.segment1.price` matches `supply.price`.

The `features` array modifies the default list. Every entry requires `field` and may specify `id`, `file`, `asset`, `commodity`, and `weight`.

```json
"features": [
  {
    "id": "electricity_demand",
    "field": "demand",
    "commodity": "Electricity",
    "weight": 2.0
  }
]
```

An entry with an explicit `id` overrides the existing feature with that ID,
even when its field, file or scope changes. A new ID adds a feature. Without an
ID, an entry overrides only an exact match of `field`, `file`, `asset` and
`commodity`, including omitted selector values; a different scope adds a feature.
An override retains existing selector values and weight when they are omitted
from the new entry. `field` remains required. Multiple exact matches are
ambiguous and require an explicit ID.

For example, `{"asset": "ThermalPower", "field": "availability", "weight": 2}`
adds a scoped feature alongside the generic default. Adding `"id": "availability"`
instead overrides that default, restricting it to ThermalPower.

During discovery, the most specific matching selector wins; equally specific
overlapping selectors remain an error. `exclude` uses the same selector fields
and removes a feature when every supplied field matches.

Every explicit `timeseries` descriptor is materialized in the reduced case. It contributes to clustering only when it matches a default or user-specified feature and is not excluded. This retains all time-dependent inputs while keeping feature selection under user control.

Physical CSV path/header pairs are read once even when several inputs reference them. Their clustering weight is the feature weight multiplied by the number of logical occurrences.

### Example: override a default feature

This overrides the built-in `demand` feature by its ID with an Electricity-only version and gives it twice the default weight.

```json
"features": [
  {
    "id": "demand",
    "field": "demand",
    "commodity": "Electricity",
    "weight": 2.0
  }
]
```

### Example: add and exclude input features

This adds a more-specific VRE availability feature. It takes precedence over the generic built-in `availability` feature for matching Electricity VRE inputs. The exclusion removes the built-in `supply.max` feature entirely; its time series are still shortened in the generated case, but do not influence clustering.

```json
"features": [
  {
    "id": "electricity_vre_availability",
    "field": "availability",
    "asset": "VRE",
    "commodity": "Electricity",
    "weight": 3.0
  }
],
"exclude": [
  { "id": "supply_max" }
]
```

## Output-based features

Output-based features add model results to the clustering matrix. They are configured separately from input features and reserve a share of the total clustering weight. Within the input and output groups, feature weights and repeated occurrences retain their relative influence.

```json
"output_based_features": {
  "weight": 0.75,
  "save_features": true,
  "reuse_saved_features": false,
  "subperiod_runs": {
    "distributed": true,
    "workers": 4,
    "exclude_policy_constraints": false,
    "save_subperiod_inputs": false,
    "save_subperiod_results": false
  },
  "features": [
    { "provider": "flow", "weight": 1.0 },
    {
      "provider": "flow",
      "commodity": "Electricity",
      "asset": "VRE",
      "weight": 3.0
    }
  ]
}
```

| JSON setting | Description | JSON type | MacroEnergy type | Default |
| --- | --- | --- | --- | --- |
| `weight` | Total clustering-weight share assigned to output features. | Number strictly between `0` and `1` | `Float64` | Required |
| `features` | Output-feature selectors and their relative weights. | Non-empty array of objects | `Vector{TDROutputFeatureSpec}` | Required |
| `subperiod_runs` | Controls for isolated candidate-period solves. | Object | `TDRSubperiodRunSettings` | `{}` |
| `save_features` | Write assembled output profiles and metadata for later reuse. | Boolean | `Bool` | `false` |
| `reuse_saved_features` | Reuse validated saved output profiles when available. | Boolean | `Bool` | `false` |

`output_based_features` and `subperiod_runs` contain only user-supplied settings; their constructors supply any omitted defaults shown in these tables.

`output_based_features.features` entries require a string `provider`; optional `id`, `asset`, and `commodity` selectors are strings, and `weight` is a positive number with default `1.0`.

| `subperiod_runs` setting | Description | JSON type | MacroEnergy field type | Default |
| --- | --- | --- | --- | --- |
| `distributed` | Use worker processes for independent period solves. | Boolean | `Bool` | `false` |
| `workers` | Maximum TDR-created workers; must be `1` when not distributed. | Positive integer | `Int` | `1` |
| `exclude_policy_constraints` | Remove all policies with `true`, or only the named policies with a list; `false` retains all policies. | Boolean or array of strings | `Union{Bool,Vector{String}}` | `false` |
| `save_subperiod_inputs` | Retain isolated input directories. | Boolean | `Bool` | `false` |
| `save_subperiod_results` | Retain each isolated provider result. | Boolean | `Bool` | `false` |

`weight` is the total output-feature share; input features receive the remaining share. A result matched by more than one feature uses the most specific matching selector, so Electricity VRE flows in the example receive weight `3.0`, not `4.0`. Equal-specificity overlapping selectors are an error.

Built-in providers are `"flow"` and `"storage_level"`. A provider returns a long `DataFrame` with `time`, `component_id`, and `value` columns. Case-specific providers through user additions are planned for a future release; for now, additional providers must be added to MacroEnergy itself.

Output-based preprocessing materializes and solves one temporary input-only case for every candidate period; it never loads the full-horizon case. Each isolated case uses the selected System’s input manifest to copy only its dependencies, with the same time-series column selection as private System inputs, plus user additions. In a multi-System Case, every `(System, candidate period)` is an independent operational solve. These solves use a one-period `PerfectForesight` horizon, so they do not model investment, state carry-over, or interactions between Systems. Set `distributed` and `workers` to run the complete set of independent solves concurrently. The worker count is a global cap across all Systems, and only TDR-created workers are removed when preprocessing finishes. `exclude_policy_constraints` defaults to `false`. Set it to `true` to remove all policy constraints, or provide a list such as `["AggregatedDemandConstraint", "CO2CapConstraint"]` to remove only those policies. An empty list retains all policies. Names must identify known `PolicyConstraint` subtypes; unknown names and non-policy constraints are errors. These rules apply to JSON and CSV inputs, including associated policy budgets and penalties. The former `include_policy_constraints` setting is no longer accepted.

Single- and multi-System sources use the same Case-settings materialization workflow. Explicit Cases supply their Case-level settings, while standalone Systems use `settings/case_settings.json` or the loader defaults. Each isolated case retains these settings, selects the original System's `PeriodLengths` entry, and sets `ExpansionHorizon` to `"PerfectForesight"`. The resulting settings are written to the isolated case's `settings/case_settings.json`.

Temporary cases are removed by default. Set `save_subperiod_inputs` to materialize retained isolated inputs before any solve starts; those exact directories are then used by the workers and remain available for live debugging. Set `save_subperiod_results` to retain compact provider outputs. Retained artifacts are written below `source/TDR/subperiod_solves/system_<n>/subperiod_<p>/`, with results in `results.json.gz`. `system_<n>` identifies a System in the original Case; `subperiod_<p>` identifies a candidate subperiod, padded to four digits (for example, `subperiod_0001`). Single-System Cases use `system_1` too.

Set `save_features` to write the assembled output profiles to `source/TDR/output_features/output_features.csv.gz` and their metadata to `source/TDR/output_features/output_metadata.json`. In multi-System Cases, each System instead uses `source/TDR/output_features/system_<n>/`. Here, `source` is the original directory passed as `source_case_path`, not the reduced destination. Rows are ordered by `Period_Index` and then `Time_Index`. Set `reuse_saved_features` to reload those validated artifacts and skip every matching System's subperiod solves; MacroEnergy validates a versioned SHA-256 fingerprint of the System definition, referenced input files, Case settings, user additions, input horizon, candidate-period length, policy-constraint inclusion, and output-feature selection before reuse. If no saved feature files exist, MacroEnergy warns and generates the features; set `save_features` as well to retain them for the next run.

Cache lookup and saving both use the original source directory. You can therefore reuse saved features when clustering the same source inputs into a new destination, or when replacing a destination with `overwrite=true`. Source `TDR/` artifacts are excluded from ordinary case copying. Existing caches in reduced destination directories are not automatically migrated. Caches without the current fingerprint must be regenerated; moving them alone does not make them reusable. Stale caches and caches from older formats produce a warning and trigger new subperiod solves. Internally, `TDROutputCacheFingerprint` holds the digest and a typed `TDROutputCacheInputs` payload, with typed file-hash and feature-selection entries. System and Case definitions retain their flexible JSON structure. JSON conversion occurs when hashing or saving metadata; changes to the validity fields or their interpretation require a cache-version review. File hashes are streamed without parsing CSVs, and shared files are hashed once per preprocessing run across all Systems. The first implementation hashes whole referenced files, so changing an unused column or file formatting can conservatively invalidate a cache. Relative paths keep fingerprints independent of the source directory’s location; generated `TDR/` artifacts are excluded.

Changing the representative count, clustering method, scaling, extreme-period selection, or feature weights does not invalidate saved output profiles. Current feature weights are applied when loading cached profiles. Solver choice and optimizer attributes also do not invalidate the cache. Cache metadata and subperiod provenance record the optimizer identity and explicitly supplied optimizer attributes where available; these are not a complete set of solver defaults. Reused-feature provenance retains the solver information from the original feature generation.

Output-based TDR currently supports a single Monolithic model period. Pass solver options explicitly through `output_feature_run_kwargs`, for example:

```julia
preprocess_inputs(
    "path/to/full_case",
    "path/to/reduced_case";
    tdr_settings_path="path/to/tdr_settings.json",
    output_feature_run_kwargs=(optimizer=HiGHS.Optimizer,),
)
```

### Example: Gurobi subperiod solves

The solver is supplied in Julia rather than in the JSON settings. This example runs up to four isolated subperiod solves concurrently. `Threads => 1` avoids multiplying Gurobi threads by the number of TDR workers; adjust it deliberately if the available compute allocation supports more threads per solve.

```julia
using Gurobi
using MacroEnergy

preprocess_inputs(
    "path/to/full_case",
    "path/to/reduced_case";
    tdr_settings_path="path/to/tdr_settings.json",
    output_feature_run_kwargs=(
        optimizer=Gurobi.Optimizer,
        optimizer_attributes=(
            "Method" => 2,
            "Crossover" => 0,
            "BarConvTol" => 1e-3,
            "Threads" => 1,
            "OutputFlag" => 0,
        ),
    ),
)
```

Set the corresponding worker count in the settings:

```json
"output_based_features": {
  "weight": 0.5,
  "subperiod_runs": {
    "distributed": true,
    "workers": 4
  },
  "features": [
    { "provider": "flow", "weight": 1.0 }
  ]
}
```

## Combined configuration example

The following complete settings file combines scoped input features, an exclusion, forced extreme periods, output-based features, distributed Gurobi-compatible subperiod settings, and reusable saved output features. Use it with the Julia call above.

```json
{
  "timesteps_per_representative_period": 168,
  "representative_periods": 12,
  "method": {
    "name": "kmeans",
    "settings": { "restarts": 3 }
  },
  "scaling": "standardize",
  "features": [
    {
      "id": "demand",
      "field": "demand",
      "commodity": "Electricity",
      "weight": 2.0
    },
    {
      "id": "electricity_vre_availability",
      "field": "availability",
      "asset": "VRE",
      "commodity": "Electricity",
      "weight": 3.0
    }
  ],
  "exclude": [
    { "id": "supply_max" }
  ],
  "extreme_periods": [
    {
      "feature": { "field": "demand", "commodity": "Electricity" },
      "aggregation": "integral",
      "select": "max"
    },
    {
      "feature": { "field": "availability", "asset": "VRE", "commodity": "Electricity" },
      "aggregation": "peak",
      "select": "min"
    }
  ],
  "output_based_features": {
    "weight": 0.5,
    "save_features": true,
    "reuse_saved_features": true,
    "subperiod_runs": {
      "distributed": true,
      "workers": 4,
      "exclude_policy_constraints": false,
      "save_subperiod_inputs": false,
      "save_subperiod_results": false
    },
    "features": [
      { "provider": "flow", "weight": 1.0 },
      {
        "provider": "flow",
        "asset": "VRE",
        "commodity": "Electricity",
        "weight": 3.0
      },
      { "provider": "storage_level", "commodity": "Electricity", "weight": 1.0 }
    ]
  }
}
```

## Extreme periods

Extreme periods reserve representative-period slots before the remaining periods are clustered. Each entry selects matching physical time series, sums them, and selects either the largest/smallest period integral or the period containing the largest/smallest individual value.

```json
"extreme_periods": [
  {
    "feature": { "field": "demand", "commodity": "Electricity" },
    "aggregation": "integral",
    "select": "max"
  },
  {
    "feature": { "field": "availability", "asset": "VRE" },
    "aggregation": "peak",
    "select": "min"
  }
]
```

`aggregation` is `"integral"` or `"peak"`; `select` is `"max"` or `"min"`. Duplicate selections reserve only one representative-period slot.

## Temporal requirements

TDR currently supports hourly inputs only. All discovered time series must cover the same explicit subperiod horizon. The requested representative-period length must not exceed the source `HoursPerSubperiod`, even for inputs without a period map: separate source periods are not assumed to form a continuous sequence.

Some cases retain `TotalHoursModeled = 8760` with 52 weekly subperiods, so their explicit grid has only 52 × 168 = 8736 hours. TDR accepts a full 8760-hour source series in this case, uses its first 8736 hours, and records the remaining 24 hours in the provenance and preprocessing log. This follows MacroEnergy's existing fixed-week weighting and padding convention.

Mixed-resolution input series and total-based resampling are not yet supported.

## How TDR works

TDR selects actual periods from the source inputs, retains their hourly profiles,
and records which original periods they represent. The generated case uses the
ordinary MacroEnergy loader and solver; the period map carries the information
needed to weight the retained periods.

### Function workflow

The trees below show the current implementation. Function calls have parentheses;
bracketed notes explain the purpose of a step and can name the function used.
`IF`, `ELSE`, and `FOR EACH` identify branches and iteration. `(...)` omits
arguments where their details would obscure the flow. The dotted connection
below `preprocess_inputs(...)` separates the general preprocessing entry point
from TDR; it does not represent another step implemented today. The
[preprocessing overview](../Preprocessing.md#preprocessing-workflow) shows the
shorter Case-level workflow.

```text
preprocess_inputs(source_root, output_root; tdr_settings_path, ...)
⋮
[TDR workflow within preprocessing]
├─ [Read settings and prepare validated input data before copying]
│  ├─ [Find number of systems using tdr_system_entries(source_root)]
│  ├─ load_tdr_settings_by_system(tdr_settings_path, number_of_systems)
│  └─ tdr_prepare_inputs(source_root, settings_by_system; definition)
│     ├─ [Validate the number of settings objects against the Systems]
│     ├─ [Read Case settings and shared cache dependencies when needed]
│     └─ FOR EACH (system_index, settings)
│        ├─ [Discover dependencies using tdr_system_input_manifest(...)]
│        ├─ [Normalize JSON and model CSV using tdr_read_input_data(...); reuse shared reads]
│        ├─ [Read and validate the time grid using tdr_full_length(...)]
│        ├─ tdr_build_candidate_periods(time_data, source_root, settings)
│        │  └─ [Read an existing period map using tdr_existing_period_map(...)]
│        ├─ [Discover physical series using tdr_sources(..., time_grid, input_data)]
│        ├─ IF output features are enabled
│        │  └─ [Prepare isolated Case settings using tdr_single_system_case_settings(...)]
│        └─ IF saving or reusing output features
│           └─ [Fingerprint source inputs using tdr_output_cache_fingerprint(...; prepared)]
│
├─ copy_case(source_root, output_root; prepared, settings_path, ...)
│  ├─ [Check source/destination separation and overwrite requirements]
│  └─ tdr_copy_input_manifest!(...; prepared, settings_path, ...)
│     └─ [Copy Case inputs and supporting files; include an in-source TDR settings file]
│
├─ tdr_prepare_system_inputs!(output_root, prepared)
│  ├─ FOR EACH prepared System
│  │  ├─ [Translate snapshot paths using tdr_relocate_inputs(...)]
│  │  ├─ IF a multi-System Case
│  │  │  └─ [Copy ordinary dependencies using tdr_copy_system_input!(...); select time-series columns]
│  │  └─ [Write translated snapshots in their original formats using tdr_write_input_data(...)]
│  └─ [Write the translated System entries into system_data.json]
│
└─ tdr_time_domain_reduction(output_root, settings_by_system, working_inputs; ...)
   ├─ IF output features are enabled
   │  └─ [Obtain features before shortening any System using tdr_output_sources(...)]
   │
   ├─ FOR EACH prepared System
   │  └─ tdr_reduce_system!(output_root, settings, inputs; output_data, ...)
   │     ├─ [Reuse discovered series, time data and the candidate plan]
   │     ├─ [Prepare retained candidate profiles using tdr_candidate_sources(...)]
   │     ├─ [Select sources enabled for clustering using filter(...)]
   │     ├─ [Record retained and trimmed hours using tdr_candidate_summary(...)]
   │     ├─ IF output features are enabled
   │     │  └─ [Append prepared features and balance shares using tdr_set_clustering_weights!(...)]
   │     ├─ [Select forced representatives using tdr_extreme_period_selections(...)]
   │     │
   │     ├─ tdr_cluster(...; extreme_periods, candidate_weights=candidates.weights)
   │     │  ├─ [Validate counts and separate forced extremes from clustering candidates]
   │     │  ├─ FOR EACH clustering source
   │     │  │  ├─ [Scale values using tdr_scale(...)]
   │     │  │  └─ [Apply the feature weight and fill the matrix]
   │     │  ├─ tdr_cluster_candidates(matrix, candidate_periods, weights, cluster_count, settings)
   │     │  │  ├─ [Expand weighted observations using tdr_weighted_candidates(...)]
   │     │  │  ├─ [Fit the configured method using MacroEnergyTimeReduction.cluster(...)]
   │     │  │  ├─ [Choose distinct source candidates using tdr_distinct_representatives(...)]
   │     │  │  └─ [Translate backend assignments to one assignment per original candidate]
   │     │  └─ [Combine forced extremes; sort representatives; map representatives to themselves]
   │     │
   │     ├─ [Find selected source rows using tdr_candidate_rows(...)]
   │     ├─ [Reduce CSV and inline JSON inputs using tdr_write_reduced_sources!(...)]
   │     ├─ tdr_write_time_data!(..., representatives, period_map, candidates)
   │     │  ├─ [Update period length and count using tdr_reduced_time_data(...)]
   │     │  ├─ [Rebuild chronological occurrences using tdr_compose_period_map(...)]
   │     │  └─ [Write period_map.csv and the time-data JSON]
   │     └─ [Build provenance and the log using tdr_preprocess_log_data(...)]
   │
   ├─ IF a multi-System Case
   │  └─ [Consolidate reduced CSVs and directly referenced JSON using tdr_consolidate_shared_inputs!(..., prepared_systems)]
   ├─ [Assemble Case-level records; group by System for multi-System Cases]
   └─ tdr_write_preprocessing_logs!(case_root, provenance, log_data)
```

`preprocess_inputs(...)` and `time_domain_reduction(...)` are the validated
entry points. Preparation builds each System's candidate plan once and discovers
its physical series once, before any destination replacement or input mutation.
The internal orchestration and reduction functions consume prepared data rather
than repeating that work. Path translation changes the file locations in the
snapshots while sharing the original series values and candidate plan. No global
prepared-input cache is retained between preprocessing calls.

Each prepared System carries its dependency manifest, parsed input snapshots, discovered
`sources`, time-grid metadata, `trailing_hours`, and `candidates`, together with
isolated Case settings and an output-cache fingerprint when needed.
`TDRTrackedInput` describes file dependencies and required columns;
`TDRCandidatePeriods` describes temporal ranges, chronological occurrences,
weights, and representative labels. `input_data` holds the normalized snapshots;
`csv_tables` retains original model CSV tables for format-preserving writes.
Consolidation uses the CSV paths and parsed-input file list already present in the prepared data, while reading the modified files
when comparing contents and rewriting references.

Single- and multi-System Cases use the same orchestration loop. A single-System
Case retains paths in the general copy; multi-System Cases receive private trees.
The single-System cache location and ungrouped provenance/log format are retained.

The optional output-feature branch expands as follows. A valid saved cache
bypasses the candidate solves. Otherwise each stored candidate is solved once;
its occurrence weight influences clustering afterwards.

```text
tdr_output_sources(case_root, settings_by_system, prepared_systems; ...)
├─ FOR EACH prepared System with output features enabled
│  ├─ [Use the fingerprint computed during source preparation]
│  ├─ IF reuse is enabled and saved features exist
│  │  └─ tdr_load_output_features(...; fingerprint)
│  │     ├─ [Valid cache: retain features and skip this System's solve tasks]
│  │     └─ [Fingerprint mismatch: regenerate features]
│  └─ IF features must be generated
│     ├─ [Prepare one reusable solve snapshot using tdr_prepare_subperiod_inputs(inputs)]
│     └─ FOR EACH candidate period
│        ├─ IF retaining subperiod inputs
│        │  └─ tdr_save_subperiod_inputs!(inputs, period, settings; ...)
│        │     └─ tdr_materialize_subperiod_case!(inputs, destination, period, settings)
│        │        ├─ tdr_copy_subperiod_case(inputs, destination)
│        │        │  ├─ [Translate the prepared snapshot using tdr_relocate_inputs(...)]
│        │        │  └─ [Copy dependencies and write cached inputs in their original formats and isolated Case settings]
│        │        ├─ [Select the candidate's prepared source range]
│        │        ├─ [Write candidate rows using tdr_write_reduced_sources!(...)]
│        │        ├─ [Set length and one subperiod using tdr_write_subperiod_time_data!(...)]
│        │        └─ IF policy constraints are excluded
│        │           └─ [Remove policy constraints using tdr_remove_policy_constraints!(...)]
│        └─ [Queue a TDRSubperiodTask]
│
├─ IF solve tasks were queued
│  └─ tdr_run_subperiod_tasks(tasks, inputs_by_system)
│     ├─ IF distributed
│     │  └─ [Cache prepared snapshots once per worker using CachingPool(...)]
│     └─ FOR EACH task [serial or distributed]
│        └─ tdr_run_subperiod(task, inputs)
│           ├─ IF inputs were not retained
│           │  └─ [Materialize temporary inputs using tdr_materialize_subperiod_case!(...)]
│           ├─ tdr_solve_subperiod_case(...)
│           │  └─ tdr_solve_subperiod_case_impl(...)
│           │     ├─ [Load the isolated Case using load_case(...)]
│           │     ├─ [Create the configured optimizer using create_optimizer(...)]
│           │     ├─ [Solve the isolated Case using solve_case(...)]
│           │     └─ [Postprocess the solution using postprocess!(...)]
│           └─ [Extract selected provider outputs using tdr_subperiod_output_data(...)]
│
└─ FOR EACH System whose features were generated
   ├─ [Assemble feature profiles using tdr_output_sources_from_results(...)]
   ├─ IF saving features
   │  └─ [Save features under source/TDR/output_features/ using tdr_write_output_features!(...)]
   ├─ IF retaining subperiod results
   │  └─ FOR EACH candidate result
   │     └─ [Save results under source/TDR/subperiod_solves/ using tdr_save_subperiod_results!(...)]
   └─ [Return feature sources and solve provenance]
```

The direct `time_domain_reduction(case_path, settings)` entry point performs the
same validation and preparation, then joins `tdr_time_domain_reduction(...)`
without `copy_case(...)`. It modifies the supplied Case directory. Internal
helpers require the prepared inputs described above. Running the final reduced
model is a separate `run_case(output_root; ...)` call; only the optional
output-feature branch solves models during preprocessing.

### Discover and copy the inputs

`preprocess_inputs` starts at `system_data.json` and follows its input-path
references through the referenced JSON files, model-input CSV files and directories. It copies those
inputs into the output case, along with supporting Julia files, Markdown files,
and `user_additions/`. This creates the working copy that TDR modifies.

For each System, TDR reads its time data to determine the explicit hourly
horizon. It searches the normalized JSON and model CSV inputs for explicit `timeseries`
descriptors and numeric inline vectors matching the source time-series length,
independently of whether their fields are configured for clustering. Scalar and
one-element constant inputs remain unchanged. CSV path/header pairs identify physical series: repeated
references to the same pair share one series, with their logical occurrences
recorded separately.

Discovery and clustering-feature selection serve different purposes. Every
explicit CSV time-series descriptor and matching-length numeric inline vector
is discovered for reduction, but only matching, non-excluded features influence
clustering. Unselected and explicitly excluded vectors are still reduced and
sliced for isolated subperiod solves. The user-supplied exclusion list is not
expanded during discovery. Inline vectors use the same explicit-horizon and
full-source-length rules as CSV series, including permitted trailing-source trimming.

Length-based recognition assumes matching-length numeric vectors are temporal.
Short segment-indexed NSD arrays and legacy supply arrays can coincidentally
match a short horizon and be treated as temporal; migration to named per-segment
inputs is a planned follow-up.

### Prepare separate inputs for multiple Systems

A single-System case retains its input paths within the copied case. For a
multi-System case, preparation builds a separate dependency manifest from each
System entry in `system_data.json`. It follows nested references in JSON and
model-input CSV files, including ordinary paths and time-series descriptors, and includes the immediate files in referenced input directories.
Only that System's dependencies are copied into `inputs/system_<n>/`, preserving
their complete source-relative paths. Internally, a manifest is a dictionary
keyed by source path, with one `TDRTrackedInput` entry per dependency. Each entry
keeps its source path, destination path, and required columns together. For example:

```text
Source input                  System 1 copy
system/time_data.json      -> inputs/system_1/system/time_data.json
system/nodes.json          -> inputs/system_1/system/nodes.json
system/demand.csv          -> inputs/system_1/system/demand.csv
assets/vre.json            -> inputs/system_1/assets/vre.json
data/availability.csv      -> inputs/system_1/data/availability.csv
nodes.json                 -> inputs/system_1/nodes.json
```

The corresponding System entry in `system_data.json` and the nested paths in
its copied JSON and model-input CSV files are rewritten to these locations. Paths remain relative
to the case root. This gives each System its own inputs to shorten when it
selects different representative periods. Shared dependencies receive a private
copy for every System that references them, regardless of directory name.
Case-level settings and supporting scripts remain available in the general case
copy.

Model-input CSVs (with `Type` and `id` columns) are parsed lazily using the
ordinary CSV-to-dictionary parser. Dependency discovery, feature selection and
path rewriting then use the same nested representation as JSON inputs. Copied
model inputs remain CSV: a format adapter transfers the adjusted values back
through the original headers' `--` addresses, preserving row order, column order
and unchanged cell values. Both ordinary `path` references and
`timeseries--path` references participate; no temporary JSON files are generated.
These same snapshots and CSV tables are reused for isolated subperiod inputs.
If policy constraints are excluded there, their corresponding CSV columns are
omitted; the remaining columns retain their original order.
After reduction, consolidation also rewrites references in model CSV consumers.

For a CSV referenced exclusively through `timeseries` descriptors, each private
copy retains the union of headers requested by that System, in source-column
order, along with recognized time/index columns (`time_index`, `time`, `index`,
`hour`, and `datetime`, ignoring case). This includes referenced series excluded
from clustering, since the generated model still needs them. A CSV referenced
as an ordinary input file or included in an ordinary input-directory reference
is copied intact. That complete-file requirement takes precedence if the same
file is also used through time-series descriptors. Column selection occurs
during private copying, before representative-period rows are selected.

### Construct candidate periods and clustering profiles

TDR splits each source subperiod independently into complete blocks of
`timesteps_per_representative_period` hours. These blocks are the candidate
periods; they never cross source-subperiod boundaries. This is the same workflow
for initial clustering and reclustering. Without a source period map, each
source period occurs once. With a map, its representative's occurrence count
becomes the weight of each child candidate.

A 168-hour source period gives seven 24-hour candidates. At a length of 20,
it gives eight candidates and trims its final eight hours. TDR reports both the
stored hours omitted and their occurrence-weighted represented hours, and
records them in provenance and the preprocessing log. A single 8760-hour source
period can similarly produce 52 weekly candidates with 24 trailing hours
trimmed. Longer candidate periods are rejected before destination replacement;
TDR does not join daily source periods into weeks.

Each clustering series is scaled over retained candidate hours using the chosen
scaling method. Standardization accounts for candidate occurrence weights. Its scaled values are multiplied by the square root of its
clustering weight, so the weight controls its contribution to squared distance.
The hourly profiles of all selected series are stacked into a matrix with one
column per candidate period and one row per feature/timestep combination.

If output-based features are enabled, TDR first obtains the selected provider
profiles from isolated candidate-period solves, or loads saved profiles. It
appends those profiles to the input features and allocates the configured
input/output weight shares before constructing the matrix. For both single- and multi-System
cases, output profiles are obtained before any System's input horizon is
shortened.

### Select extremes and cluster the remaining periods

Extreme-period rules operate on the original, unscaled feature values. Each
rule sums its matching physical series and selects a period using its integral
or peak criterion. Duplicate selections reserve one slot. Forced extreme
periods are removed from the regular clustering candidates and each represents
itself in the period map.

The remaining representative-period slots are filled by the configured
clustering method. Candidate occurrence weights influence selection as well as
final model weights. The clustering backend receives repeated candidate columns
according to integer occurrence counts, divided by their common divisor to
avoid unnecessary repetitions. This supports all configured methods, including
autoencoder training. Unequal counts can increase backend memory and computation,
including its pairwise distance matrix. Each regular candidate is assigned to a cluster, and each
cluster supplies an actual source period as its representative. The final
representatives, including forced extremes, are sorted by source-period index.

For example, suppose six daily candidates are reduced to two representatives,
days 2 and 5, with assignments `[1, 1, 1, 2, 2, 2]`. The retained hourly inputs
come from those two days, and the assignments record how all six days are
represented. The exact selections and assignments depend on the data, method,
and settings.

### Write the retained hourly inputs

TDR selects the source rows belonging to the representative periods in their
sorted order. In the example, the output contains day 2's 24 hours followed by
day 5's 24 hours, for a total of 48 explicit hours.

For each discovered CSV, the entire table is shortened to those rows. Recognized
time/index columns are reset to consecutive indices. Discovered inline vectors
are shortened at their original locations in the copied JSON files. The values
written are the original source values; scaling is used only for clustering.

### Write the period map and load representative-period weights

TDR updates `NumberOfSubperiods` in the System's time-data file and adds a
`SubPeriodMap` reference to `period_map.csv` beside that file. For the example,
the map is:

| `Period_Index` | `Rep_Period` | `Rep_Period_Index` |
| --- | --- | --- |
| 1 | 2 | 1 |
| 2 | 2 | 1 |
| 3 | 2 | 1 |
| 4 | 5 | 2 |
| 5 | 5 | 2 |
| 6 | 5 | 2 |

`Period_Index` identifies an original period. `Rep_Period` identifies the source
period selected to represent it. `Rep_Period_Index` gives that representative's
position in the shortened inputs: source day 2 is stored first, and source day 5
second.

When the generated case is loaded, the ordinary time-data loader counts the
original periods mapped to each representative and scales their weights so
weighted subperiod hours sum to `TotalHoursModeled`. With 24-hour subperiods and
`TotalHoursModeled = 144`, the two representatives above each have weight 3.
TDR preserves `TotalHoursModeled`, even though fewer hours are explicitly stored.

TDR rebuilds the entire period map at the requested length. Each chronological
source occurrence expands into its retained child candidates, in order, and the
new `Period_Index` values run from 1 to the number of child occurrences. The
selected representative labels identify their originating occurrences in this
new chronology; weekly indices therefore become daily indices when reclustering
weeks into days. Equal-length reclustering uses the same process with one child
per source period. Stored representative profiles retain their source-label order.

Both reduced inputs and isolated output-feature inputs set `HoursPerSubperiod`
for every commodity to the requested period length. `NumberOfSubperiods` is the
number of selected representatives, or one for an isolated solve.
`TotalHoursModeled` is preserved. Consequently, trimming redistributes omitted
hours through the loader's weight normalization rather than reducing that
modeled total. Long-duration storage treatment of elapsed time omitted by
trimming remains a separate follow-up.

### Consolidate files and inspect the result

After reducing every System independently, multi-System TDR compares the
reduced CSVs in the private `inputs/system_<n>/` trees. Its consolidation step
groups byte-identical files, copies shared content back to an ordinary shared
input path, rewrites references in JSON and model-input CSVs, and removes
redundant private time-series CSVs.
Distinct content groups use separate destinations. It then consolidates
byte-identical, directly referenced JSON files at their original case-relative
locations, updating references in the System definitions and other JSON or
model CSV inputs. Comparison repeats
after references change, allowing identical parent files to share consolidated
children. Additional content groups or conflicting earlier consolidations use
separate destinations under `inputs/shared/`. Time-data files and JSON files
loaded through directory references remain private. Files without identical counterparts also remain private.

The output case stores `time_domain_reduction_provenance.json` and
`preprocess_log.json` under its `preprocessing_logs/` directory. Provenance records the settings, selected periods, source
case, and period-map location. The log records discovered features, weights and
occurrences, extreme-period decisions, temporal handling, and the original
periods assigned to every representative. Multi-System records are grouped by
System. Optional output-feature caches and retained subperiod inputs/results
are stored under the original source’s `TDR/`, as described in the output-based
features section. Saved-artifact paths in the destination’s provenance and logs
point to those source locations.

`discovered_time_series.sources` lists every input series that was reduced,
including its file/header or inline field path and whether it influenced
clustering. Each logical reference reports `include_in_clustering` and a
`clustering_exclusion_reason`: `no_matching_feature`, `explicitly_excluded`, or
`zero_clustering_weight` when an eligible input receives no clustering weight.
Clustering references have a `null` reason. `clustering_features.sources` lists
the series actually used, including output features; generated output profiles
are marked `reduced=false` because they are not rewritten into model inputs.

Internally, each series is represented by `TDRLogEntry`, with typed location and
reference records (`TDRLogLocation` and `TDRLogReference`). Their fields and
defaults define the source-entry schema; conversion to dictionaries preserves
the JSON layout described above.

Inspect the period map and log to understand which periods were retained and
how they represent the original horizon, then load and run the generated case
with the ordinary `load_case` and `run_case` APIs.

## Developer API

The following internal interfaces support additional clustering methods,
input-discovery behavior, and official output providers.

### Entry points and settings

```@docs
MacroEnergy.time_domain_reduction
MacroEnergy.TDRSettings
MacroEnergy.load_time_domain_reduction_settings
MacroEnergy.load_tdr_settings_by_system
MacroEnergy.default_tdr_settings
MacroEnergy.tdr_subperiod_run_settings_data
```

### Input discovery, copying, and consolidation

```@docs
MacroEnergy.TimeSeriesSource
MacroEnergy.TDRTrackedInput
MacroEnergy.tdr_normalize_path
MacroEnergy.tdr_read_input_data
MacroEnergy.tdr_write_input_data
MacroEnergy.tdr_visit_input_paths!
MacroEnergy.tdr_case_input_manifest
MacroEnergy.tdr_system_input_manifest
MacroEnergy.tdr_collect_manifest_references!
MacroEnergy.tdr_system_input_path
MacroEnergy.tdr_prepare_inputs
MacroEnergy.tdr_relocate_inputs
MacroEnergy.tdr_sources
MacroEnergy.tdr_rewrite_input_paths!
MacroEnergy.tdr_prepare_system_inputs!
MacroEnergy.tdr_copy_system_input!
MacroEnergy.tdr_shared_input_replacements
MacroEnergy.tdr_consolidate_shared_inputs!
```

### Candidate periods and clustering

```@docs
MacroEnergy.TDRCandidatePeriods
MacroEnergy.tdr_reduced_time_data
MacroEnergy.tdr_weighted_candidates
MacroEnergy.tdr_cluster_candidates
MacroEnergy.tdr_reduce_system!
MacroEnergy.tdr_set_clustering_weights!
```

### Output-feature providers and isolated inputs

```@docs
MacroEnergy.TDR_OUTPUT_PROVIDERS
MacroEnergy.tdr_flow_provider
MacroEnergy.tdr_storage_level_provider
MacroEnergy.TDROutputFeatureSpec
MacroEnergy.TDRSubperiodTask
MacroEnergy.tdr_prepare_subperiod_inputs
```

### Output-feature cache validation

```@docs
MacroEnergy.TDROutputCacheFile
MacroEnergy.TDROutputCacheFeatureSelection
MacroEnergy.TDROutputCacheInputs
MacroEnergy.TDROutputCacheFingerprint
MacroEnergy.tdr_output_feature_selection
MacroEnergy.tdr_output_cache_fingerprint
MacroEnergy.tdr_output_solver_provenance
```

### Log entries

```@docs
MacroEnergy.TDRLogLocation
MacroEnergy.TDRLogReference
MacroEnergy.TDRLogEntry
MacroEnergy.tdr_write_preprocessing_logs!
```

The TDR section of `preprocess_log.json` records temporal handling, extreme-period decisions, method settings, feature sources and weights, occurrences, and—for every representative period—the total number and list of original periods it represents.
