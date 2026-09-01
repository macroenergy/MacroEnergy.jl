using BenchmarkTools
using HiGHS
using JSON3
using Logging
using MacroEnergy

function bootstrap(case_path::AbstractString)
    MacroEnergy.materialize_user_commodities!(case_path)
    return nothing
end

if first(ARGS) == "--bootstrap"
    length(ARGS) == 2 || error("Usage: worker.jl --bootstrap CASE_PATH")
    bootstrap(abspath(ARGS[2]))
    exit()
end

length(ARGS) == 3 || error("Usage: worker.jl CASE_PATH RESULT_PATH LABEL")
const CASE_PATH, RESULT_PATH, LABEL = abspath(ARGS[1]), abspath(ARGS[2]), ARGS[3]

function scratch_case(source::AbstractString)
    root = mktempdir()
    path = joinpath(root, basename(source))
    cp(source, path; force = true)
    return path
end

function prepare_case!(path::AbstractString)
    command = `$(Base.julia_cmd()) --project=$(dirname(Base.active_project())) --startup-file=no $(@__FILE__) --bootstrap $path`
    run(command)
    isfile(MacroEnergy.user_additions_commodities_path(path)) || error("Bootstrap did not create user additions")
    MacroEnergy.load_user_additions(path)
    MacroEnergy.refresh_user_type_registries!()
    return nothing
end

load_stage(path::AbstractString) = with_logger(NullLogger()) do
    MacroEnergy.load_case_data(joinpath(path, "system_data.json"); lazy_load = true)
end

generate_case_stage(path::AbstractString, data::Dict{Symbol,Any}) = with_logger(NullLogger()) do
    MacroEnergy.generate_case(joinpath(path, "system_data.json"), data)
end

function generate_model_stage(case::MacroEnergy.Case)
    optimizer = MacroEnergy.create_optimizer(HiGHS.Optimizer, nothing, ("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3))
    return with_logger(NullLogger()) do
        MacroEnergy.generate_model(case, optimizer, MacroEnergy.solution_algorithm(case))
    end
end

function summary(trial::BenchmarkTools.Trial)
    value = median(trial)
    return Dict(:median_seconds => value.time / 1e9, :memory_bytes => value.memory, :allocations => value.allocs)
end

function run_benchmarks(path::AbstractString)
    prepare_case!(path)
    generate_case_stage(path, load_stage(path)) # warm-up; excluded from timing
    load_trial = @benchmark load_stage($path) evals = 1 samples = 5
    case_trial = @benchmark generate_case_stage($path, data) setup = (data = load_stage($path)) evals = 1 samples = 5
    model_trial = @benchmark generate_model_stage(case) setup = begin
        data = load_stage($path)
        case = generate_case_stage($path, data)
    end evals = 1 samples = 5
    return Dict(:load => summary(load_trial), :generate_case => summary(case_trial), :generate_model => summary(model_trial))
end

isdir(CASE_PATH) || error("Case directory does not exist: $CASE_PATH")
results = Dict(:label => LABEL, :benchmarks => run_benchmarks(scratch_case(CASE_PATH)))
mkpath(dirname(RESULT_PATH))
open(RESULT_PATH, "w") do io
    JSON3.write(io, results)
end
