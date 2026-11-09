#!/usr/bin/env julia
#
# setup_experiments.jl — scaffold (and optionally submit) one SLURM job per
# experiment case.
#
# Each experiment is defined by a settings file in
#     settings/experiments_settings/case_settings_<name>.json
# List the <name>s you want to run in `cases` below. For each one this script
# creates a thin sibling run folder next to this template (e.g. ../<name>) that
# shares the heavy inputs (system/, assets/, ...) via symlinks and uses the
# chosen experiment file as its settings/case_settings.json. Each case then
# runs as its own SLURM job with the shared config in benders_jobscript.sh.
#
# Because each case has its own folder, results/, logs, and the run .log never
# collide. No changes to the model code are required.
#
# The scaffolding in a case folder is ALWAYS refreshed: the symlinks, runners and
# settings are removed and rewritten, so a run never picks up stale settings.
# Output folders from previous runs (named after OutputDir in macro_settings.json,
# e.g. 082626_001) and logs/ are left untouched.
#
# On the cluster, launch it via ./run_experiments.sh (which loads the Julia
# module first). You can also run it directly (plain Base Julia, no packages):
#     julia setup_experiments.jl            # preview: refresh + print sbatch commands
#     SUBMIT=true julia setup_experiments.jl # refresh + actually submit
#
# Typical flow: preview first (submit off) to refresh and check the folders,
# then submit for real. See run_experiments.sh for the SUBMIT switch.

using Dates

# ── Configuration ─────────────────────────────────────────────────────────────
cases = [
    "nocd_nodi_noel_nocap",
    "nocd_nodi_noel_cap",
    "cd_nodi_noel_cap",
    "cd_di_noel_cap",
    "cd_di_el_cap",
]

# submit is read from the environment so the run_experiments.sh launcher can
# control it without editing this file. It defaults to false, so running
# `julia setup_experiments.jl` directly is a safe preview (rebuild the folders +
# print the sbatch commands, submit nothing).
_envflag(k) = lowercase(get(ENV, k, "false")) in ("1", "true", "yes")
submit = _envflag("SUBMIT")   # SUBMIT=true → actually sbatch each case

# ── Paths ─────────────────────────────────────────────────────────────────────
const TEMPLATE        = @__DIR__                 # this template folder (e.g. wecc_20p_11z)
const TEMPLATE_NAME   = basename(TEMPLATE)
const PARENT          = dirname(TEMPLATE)        # cases are created here, as siblings
# The experiment files live either in settings/experiments_settings/ or at the top level
# of the template; accept whichever this template uses.
const EXPERIMENTS_DIR = let nested = joinpath(TEMPLATE, "settings", "experiments_settings"),
                            toplevel = joinpath(TEMPLATE, "experiments_settings")
    isdir(nested) ? nested : toplevel
end
const JOBSCRIPT       = joinpath(TEMPLATE, "benders_jobscript.sh")

# All cases in one launch write into a single batch folder inside the template,
# named <mmddyy>_<nnn> for today's date with the next unused number (001, 002, ...).
# Each case gets its own subfolder in there, so a batch looks like:
#     <template>/091626_001/cd_di_el_cap/results_period_1/...
# The number is chosen once here, not per case, so every job in a launch agrees
# on it and concurrent jobs cannot race for the same name.
const BATCH_NAME = let tag = Dates.format(Dates.today(), "mmddyy"), n = 1
    while ispath(joinpath(TEMPLATE, "$(tag)_$(lpad(n, 3, '0'))"))
        n += 1
    end
    "$(tag)_$(lpad(n, 3, '0'))"
end
const BATCH_DIR = joinpath(TEMPLATE, BATCH_NAME)

# Case folders are namespaced by template, e.g. wecc_20p_11z_cd_di_el_cap and
# wecc_20p_11z_egsitcall_cd_di_el_cap. Without this, two templates sharing the
# same experiment names would fight over one folder: the second launch would
# repoint it at its own template while the first launch's jobs were still
# reading from it. Results inside a batch stay under the plain case name, since
# the batch folder already lives under its own template.
case_folder_name(name::AbstractString) = "$(TEMPLATE_NAME)_$(name)"

# Heavy shared inputs are symlinked; the tiny per-case files are copied.
const LINK_ITEMS    = ["system", "assets", "system_data.json", "locations.json"]
const COPY_RUNNERS  = ["Run_benders_oncluster.jl", "run_benders.jl"]
const COPY_SETTINGS = ["benders_settings.json"]  # shared, non-case-specific
# macro_settings.json is not copied verbatim: each case needs its own OutputDir
# pointing into the batch folder, so it is rewritten by write_case_macro_settings.

# ── Per-case macro_settings.json ──────────────────────────────────────────────
# Point this case's OutputDir at <batch>/<case> and set OverwriteResults so the
# model writes exactly there instead of appending its own _001 suffix. The path
# is relative to the case folder so the tree stays valid across machines, the
# same reason the heavy inputs are linked relatively.
#
# Done as text editing because this script runs on plain Base Julia, which has
# no JSON parser available.
function write_case_macro_settings(src::AbstractString, dest::AbstractString,
                                   output_dir::AbstractString)
    text = read(src, String)
    # Drop any existing entries for the two keys we are about to set...
    for key in ("OutputDir", "OverwriteResults")
        text = replace(text, Regex("[ \\t]*\"$key\"[ \\t]*:[^,\n]*,?[ \\t]*\\r?\\n?") => "")
    end
    # ...then repair the trailing comma if the key we removed was the last one.
    text = replace(text, r",(\s*)\}(\s*)$" => s"\1}\2")

    brace = findfirst('{', text)
    brace === nothing && error("Not a JSON object: $src")
    rest = text[nextind(text, brace):end]
    comma = occursin('"', rest) ? "," : ""   # omit if no other keys remain
    injected = "{\n    \"OutputDir\": \"$(escape_string(output_dir))\",\n" *
               "    \"OverwriteResults\": true$comma"
    write(dest, text[1:prevind(text, brace)] * injected * rest)
    return nothing
end

# ── Build one case folder ─────────────────────────────────────────────────────
# Always refreshes the scaffolding (symlinks, runners, settings) so a run can
# never pick up stale settings, while leaving everything a previous run produced
# (results*/, logs/, slurm .out files) in place.
function build_case(name::AbstractString)
    src_settings = joinpath(EXPERIMENTS_DIR, "case_settings_$(name).json")
    isfile(src_settings) || error("Missing settings file: $src_settings")

    case_dir = joinpath(PARENT, case_folder_name(name))
    if ispath(case_dir)
        @info "Refreshing case folder, keeping previous results: $case_dir"
        # Remove only what this script puts there. Everything else the case
        # accumulated is kept: logs/ and the output folders, which are named
        # after OutputDir in settings/macro_settings.json (e.g. 082626_001,
        # 082626_002, ...), not necessarily "results".
        # rm() on a symlink removes the link itself, never the shared target.
        for item in [LINK_ITEMS; COPY_RUNNERS; "settings"; ".macro_case"]
            path = joinpath(case_dir, item)
            (islink(path) || ispath(path)) && rm(path; recursive=true, force=true)
        end
    end

    mkpath(case_dir)

    # Symlink the heavy shared inputs. The target is relative (../<template>/item)
    # so the tree stays valid across machines (laptop vs cluster).
    for item in LINK_ITEMS
        target = joinpath(TEMPLATE, item)
        ispath(target) || error("Template missing '$item': $target")
        symlink(joinpath("..", TEMPLATE_NAME, item), joinpath(case_dir, item))
    end

    # Copy the tiny runner scripts
    for item in COPY_RUNNERS
        cp(joinpath(TEMPLATE, item), joinpath(case_dir, item))
    end

    # Settings: copy the shared settings, then drop in the chosen experiment file
    # as this case's case_settings.json.
    settings_dir = joinpath(case_dir, "settings")
    mkpath(settings_dir)
    for item in COPY_SETTINGS
        cp(joinpath(TEMPLATE, "settings", item), joinpath(settings_dir, item))
    end
    cp(src_settings, joinpath(settings_dir, "case_settings.json"))

    # Send this case's outputs to <batch>/<case>, addressed relatively from the
    # case folder: ../<template>/<batch>/<case>
    write_case_macro_settings(
        joinpath(TEMPLATE, "settings", "macro_settings.json"),
        joinpath(settings_dir, "macro_settings.json"),
        joinpath("..", TEMPLATE_NAME, BATCH_NAME, name),
    )

    # Marker (lets tooling tell generated cases apart) + slurm log dir
    touch(joinpath(case_dir, ".macro_case"))
    mkpath(joinpath(case_dir, "logs"))

    return case_dir
end

# ── Submit one case ───────────────────────────────────────────────────────────
function submit_case(name::AbstractString, case_dir::AbstractString)
    cmd = `sbatch --job-name=$(basename(case_dir)) --chdir=$(case_dir) $(JOBSCRIPT)`
    if submit
        run(cmd)
    else
        println("[dry-run] ", cmd)
    end
end

# ── Run ───────────────────────────────────────────────────────────────────────
isdir(EXPERIMENTS_DIR) || error("Experiments settings folder not found: $EXPERIMENTS_DIR")
isfile(JOBSCRIPT)      || error("Jobscript not found: $JOBSCRIPT")

# Claim the batch folder now so a second launch on the same day takes the next
# number rather than reusing this one.
mkpath(BATCH_DIR)
println("Results for this batch: $BATCH_DIR\n")

for name in cases
    case_dir = build_case(name)
    println("Prepared case: $case_dir")
    submit_case(name, case_dir)
end

println("\nDone. ", submit ? "Submitted" : "Scaffolded (submit=false, nothing submitted)",
        " $(length(cases)) case(s).")
println("Each case writes its results to $BATCH_DIR/<case name>/")
