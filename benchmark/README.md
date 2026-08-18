# Local benchmarks

Run:

```sh
julia --project=. benchmark/run.jl
```

The wrapper benchmarks every name in `BENCHMARK_EXAMPLE_NAMES` (currently
`multisector_3zone`). It downloads version `0.2.0` once, creates a temporary worktree
from `upstream/main`, and runs the same BenchmarkTools worker under that public baseline
and the current dirty project. Workers use private input copies and prepare runtime user
additions. No solver or external benchmark tool is required.

The ignored `benchmark/results/results.json` contains both revisions for every example,
per-stage time, allocations, and allocated bytes, plus a geometric-mean speedup and
average allocation/memory improvements. Temporary per-worker result files are removed.

To compare with your local `main` instead, run:

```sh
julia --project=. -e 'include("benchmark/benchmark_helpers.jl"); benchmark_examples(main_revision="main")'
```
