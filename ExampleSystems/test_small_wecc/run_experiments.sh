#!/bin/bash
#
# run_experiments.sh — load Julia and run setup_experiments.jl to scaffold and
# submit the experiment cases listed in that file.
#
# This is the "go" launcher for the cluster: it loads the Julia module, then
# runs the Julia driver. By default it SUBMITS the jobs. Edit the experiment
# settings (experiments_settings/) and the `cases` list in setup_experiments.jl
# first.
#
# The scaffolding in each case folder is ALWAYS refreshed (symlinks, runners and
# settings are rewritten), so a run never picks up stale settings. Results from
# previous runs and logs/ are kept.
#
# Usage (from within this template folder):
#   ./run_experiments.sh              # refresh + submit all cases
#   DRY_RUN=1 ./run_experiments.sh    # refresh + print sbatch commands (submit nothing)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

module purge
module load julia/1.12.1

# This launcher submits by default; DRY_RUN=1 turns submission off for a preview.
if [[ "${DRY_RUN:-0}" == "1" ]]; then
    export SUBMIT=false
else
    export SUBMIT=true
fi

julia "$HERE/setup_experiments.jl"
