# Time-Domain Reduction

`preprocess_inputs` creates a new, ordinary MacroEnergy case directory from an existing case. The source case is unchanged, and the generated directory loads with `load_case` and runs with `run_case` without TDR-specific run settings.

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

### Clustering methods

| `method.name` | Description |
| --- | --- |
| `"kmeans"` | Clusters input profiles and chooses the real period nearest each centroid. |
| `"kmedoids"` | Clusters using pairwise distances and selects medoid periods. |
| `"autoencoder_sequential"` | Trains an autoencoder, then runs k-means in its latent space. |
| `"autoencoder_simultaneous"` | Trains an autoencoder with reconstruction and clustering-aware loss, then runs k-means in its latent space. |

All methods accept `restarts` and `v` in `method.settings`. Autoencoder methods additionally accept the following settings; these are their defaults.

```json
"settings": {
  "restarts": 0,
  "kernel_size": 3,
  "stride": 1,
  "epochs": 50,
  "min_err_diff": 0.0001,
  "patience": 10,
  "warmup": 5,
  "n_filters": 8,
  "latent_dim": 4
}
```

`"autoencoder_simultaneous"` also accepts `"lambda"`, which defaults to `0.1`. Training occurs during preprocessing and does not write latent-space cache files into the case directory.

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

A matching user feature replaces one unambiguous default feature; otherwise it adds a feature. `exclude` uses the same selector fields and removes a feature when every supplied field matches.

Every explicit `timeseries` descriptor is materialized in the reduced case. It contributes to clustering only when it matches a default or user-specified feature and is not excluded. This retains all time-dependent inputs while keeping feature selection under user control.

Physical CSV path/header pairs are read once even when several inputs reference them. Their clustering weight is the feature weight multiplied by the number of logical occurrences.

### Example: override a default feature

This replaces the built-in `demand` feature with an Electricity-only version and gives it twice the default weight. Matching an existing feature by its `id` and `field` is the clearest way to express an override.

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
    "include_policy_constraints": true,
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

`weight` is the total output-feature share; input features receive the remaining share. A result matched by more than one feature uses the most specific matching selector, so Electricity VRE flows in the example receive weight `3.0`, not `4.0`. Equal-specificity overlapping selectors are an error.

Built-in providers are `"flow"` and `"storage_level"`. Other names resolve to a MacroEnergy function of the same name, allowing user additions to provide further result accessors. A provider must return a long `DataFrame` with `time`, `component_id`, and `value` columns.

Output-based preprocessing materializes and solves one temporary input-only case for every candidate period; it never loads the full-horizon case. Set `distributed` and `workers` to run those independent solves concurrently. The worker count caps TDR-created workers, and only those workers are removed when preprocessing finishes. `include_policy_constraints` defaults to `true`; set it to `false` to remove policy constraints from the temporary inputs.

Temporary cases are removed by default. Set `save_subperiod_inputs` to materialize retained isolated inputs before any solve starts; those exact directories are then used by the workers and remain available for live debugging. Set `save_subperiod_results` to retain compact provider outputs. Retained artifacts are written below `TDR/subperiod_solves/period_<n>/`, with results in `results.json.gz`.

Set `save_features` to write the assembled output profiles to `TDR/output_features/output_features.csv.gz` and their metadata to `TDR/output_features/output_metadata.json`. Rows are ordered by `Period_Index` and then `Time_Index`. Set `reuse_saved_features` to reload those validated artifacts and skip every subperiod solve; MacroEnergy checks the input horizon, representative-period length, and output-feature specifications before reuse. If no saved feature files exist, MacroEnergy warns and generates the features; set `save_features` as well to retain them for the next run.

When `preprocess_inputs(...; overwrite=true)` recreates an existing output case and `reuse_saved_features=true`, it preserves that output case's `TDR/output_features` directory through the copy so the cache remains available. Invalid or stale cached features are still rejected by the usual validation.

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
      "include_policy_constraints": true,
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

TDR currently supports hourly inputs only. All discovered time series must cover the same explicit subperiod horizon, and that horizon must divide evenly into the requested representative-period length.

Some cases retain `TotalHoursModeled = 8760` with 52 weekly subperiods, so their explicit grid has only 52 × 168 = 8736 hours. TDR accepts a full 8760-hour source series in this case, uses its first 8736 hours, and records the remaining 24 hours in the provenance and preprocessing log. This follows MacroEnergy's existing fixed-week weighting and padding convention.

Mixed-resolution input series and total-based resampling are not yet supported.

## Generated files

The reduced case contains its usual inputs plus a period map referenced by `time_data.json`, `time_domain_reduction_provenance.json`, and `preprocess_log.json`.

The TDR section of `preprocess_log.json` records temporal handling, extreme-period decisions, method settings, feature sources and weights, occurrences, and—for every representative period—the total number and list of original periods it represents.
