using JSON3
using MacroEnergy
using Printf
using Statistics

const BENCHMARK_EXAMPLE_NAMES = ["multisector_3zone"]
const BENCHMARK_EXAMPLE_VERSION = "0.2.0"
const BENCHMARK_STAGES = ("load", "generate_case", "generate_model")

benchmark_repo_root() = abspath(joinpath(@__DIR__, ".."))
benchmark_example_dir(repo_root::AbstractString = benchmark_repo_root()) =
    joinpath(repo_root, "examples")
benchmark_example_path(examples_dir::AbstractString, name::AbstractString) =
    joinpath(examples_dir, name)
benchmark_example_marker(examples_dir::AbstractString, name::AbstractString) =
    joinpath(examples_dir, ".$(name).version")
benchmark_results_path(repo_root::AbstractString = benchmark_repo_root()) =
    joinpath(repo_root, "benchmark", "results", "results.json")

function benchmark_example_state(
    examples_dir::AbstractString,
    name::AbstractString;
    version::AbstractString,
)
    case_path = benchmark_example_path(examples_dir, name)
    marker_path = benchmark_example_marker(examples_dir, name)
    marker_version = isfile(marker_path) ? strip(read(marker_path, String)) : nothing

    if isdir(case_path) && marker_version == version
        return :ready
    elseif !isdir(case_path) && isnothing(marker_version)
        return :missing
    end
    return :mismatch
end

function refresh_benchmark_example!(examples_dir::AbstractString, name::AbstractString)
    rm(benchmark_example_path(examples_dir, name); recursive = true, force = true)
    rm(benchmark_example_marker(examples_dir, name); force = true)
    return nothing
end

"""
    ensure_benchmark_example!(examples_dir, name;
                              version = BENCHMARK_EXAMPLE_VERSION,
                              refresh = false, downloader = download_example)

Ensure that `examples_dir` contains `name` at the requested version. The marker prevents
an existing download from silently being reused with a different benchmark input.
"""
function ensure_benchmark_example!(
    examples_dir::AbstractString,
    name::AbstractString;
    version::AbstractString = BENCHMARK_EXAMPLE_VERSION,
    refresh::Bool = false,
    downloader::Function = download_example,
)
    state = benchmark_example_state(examples_dir, name; version)
    case_path = benchmark_example_path(examples_dir, name)

    if state == :ready
        return abspath(case_path)
    elseif state == :mismatch && !refresh
        throw(
            ArgumentError(
                "Benchmark example at $(abspath(case_path)) does not match version $version. " *
                "Rerun with refresh=true to replace it.",
            ),
        )
    end

    refresh && refresh_benchmark_example!(examples_dir, name)
    mkpath(examples_dir)
    cd(dirname(abspath(examples_dir))) do
        downloader(name, basename(examples_dir); version)
    end

    isdir(case_path) || error("Expected benchmark example at $(abspath(case_path)) after download")
    write(benchmark_example_marker(examples_dir, name), version * "\n")
    return abspath(case_path)
end

function worker_command(
    project_dir::AbstractString,
    case_path::AbstractString,
    result_path::AbstractString,
    label::AbstractString,
)
    return `$(Base.julia_cmd()) --project=$(abspath(project_dir)) --startup-file=no $(joinpath(@__DIR__, "worker.jl")) $(abspath(case_path)) $(abspath(result_path)) $label`
end

instantiate_project(project_dir::AbstractString) = run(`$(Base.julia_cmd()) --project=$(abspath(project_dir)) --startup-file=no -e 'using Pkg; Pkg.instantiate()'`)
run_worker(command::Cmd) = run(command)

function with_main_worktree(f::Function, main_revision::AbstractString)
    worktree = mktempdir()
    try
        run(`git -C $(benchmark_repo_root()) worktree add --detach $worktree $main_revision`)
        return f(worktree)
    finally
        run(`git -C $(benchmark_repo_root()) worktree remove --force $worktree`)
    end
end

function run_worker_result(
    project_dir::AbstractString,
    case_path::AbstractString,
    label::AbstractString,
    worker_runner::Function,
)
    result_path, io = mktemp()
    close(io)
    try
        worker_runner(worker_command(project_dir, case_path, result_path, label))
        return JSON3.read(read(result_path, String))
    finally
        rm(result_path; force = true)
    end
end

function percentage_improvement(main_value::Real, dirty_value::Real)
    iszero(main_value) && return 0.0
    return 100 * (main_value - dirty_value) / main_value
end

function comparison_summary(benchmark_results)
    speedups = Float64[]
    allocation_improvements = Float64[]
    memory_improvements = Float64[]

    for result in values(benchmark_results), stage in BENCHMARK_STAGES
        main = result[:main][:benchmarks][Symbol(stage)]
        dirty = result[:dirty][:benchmarks][Symbol(stage)]
        main_time = main[:median_seconds]
        dirty_time = dirty[:median_seconds]
        main_time > 0 && dirty_time > 0 && push!(speedups, main_time / dirty_time)
        push!(allocation_improvements, percentage_improvement(main[:allocations], dirty[:allocations]))
        push!(memory_improvements, percentage_improvement(main[:memory_bytes], dirty[:memory_bytes]))
    end

    return Dict(
        :geometric_mean_speedup => isempty(speedups) ? 1.0 : exp(mean(log, speedups)),
        :average_allocation_improvement => isempty(allocation_improvements) ? 0.0 : mean(allocation_improvements),
        :average_memory_improvement => isempty(memory_improvements) ? 0.0 : mean(memory_improvements),
    )
end

function print_results(benchmark_results, summary)
    println("\nBenchmark comparison (main / dirty):")
    @printf("%-20s %-16s %10s %10s %9s %14s %14s %14s %14s\n",
        "example", "stage", "main (s)", "dirty (s)", "speedup", "main allocs", "dirty allocs", "main bytes", "dirty bytes")
    for (name, result) in sort(collect(benchmark_results); by = first), stage in BENCHMARK_STAGES
        main = result[:main][:benchmarks][Symbol(stage)]
        dirty = result[:dirty][:benchmarks][Symbol(stage)]
        speedup = iszero(dirty[:median_seconds]) ? Inf : main[:median_seconds] / dirty[:median_seconds]
        @printf("%-20s %-16s %10.3f %10.3f %8.2fx %14d %14d %14d %14d\n",
            name, stage, main[:median_seconds], dirty[:median_seconds], speedup,
            main[:allocations], dirty[:allocations], main[:memory_bytes], dirty[:memory_bytes])
    end
    @printf("\nGeometric-mean speedup: %.2fx; average allocation improvement: %.1f%%; average memory improvement: %.1f%%\n",
        summary[:geometric_mean_speedup], summary[:average_allocation_improvement], summary[:average_memory_improvement])
    return nothing
end

"""
    benchmark_examples(; main_revision = "upstream/main", examples = BENCHMARK_EXAMPLE_NAMES,
                         examples_dir = benchmark_example_dir(), refresh = false,
                         results_path = benchmark_results_path())

Compare each requested example under the public `upstream/main` baseline and this dirty
worktree. A single JSON file contains both revisions and an aggregate summary.
"""
function benchmark_examples(
    ;
    main_revision::AbstractString = "upstream/main",
    examples::AbstractVector{<:AbstractString} = BENCHMARK_EXAMPLE_NAMES,
    examples_dir::AbstractString = benchmark_example_dir(),
    refresh::Bool = false,
    results_path::AbstractString = benchmark_results_path(),
    worker_runner::Function = run_worker,
)
    case_paths = Dict(name => ensure_benchmark_example!(examples_dir, name; refresh) for name in examples)
    mkpath(dirname(results_path))
    instantiate_project(benchmark_repo_root())

    benchmark_results = with_main_worktree(main_revision) do main_worktree
        instantiate_project(main_worktree)
        Dict(
            name => Dict(
                :main => run_worker_result(main_worktree, case_path, "main", worker_runner),
                :dirty => run_worker_result(benchmark_repo_root(), case_path, "dirty", worker_runner),
            ) for (name, case_path) in case_paths
        )
    end
    summary = comparison_summary(benchmark_results)
    results = Dict(:examples => benchmark_results, :summary => summary)
    open(results_path, "w") do io
        JSON3.write(io, results)
    end
    print_results(benchmark_results, summary)
    return results
end
