module TestBenchmarkRunner
using Test
using MacroEnergy
include(joinpath(@__DIR__, "..", "benchmark", "benchmark_helpers.jl"))

function mock_downloader(counter)
    return function (name, target_dir; version)
        counter[] += 1
        path = joinpath(target_dir, name)
        mkpath(path)
        write(joinpath(path, "system_data.json"), "{}")
    end
end

@testset "Benchmark runner" begin
    mktempdir() do dir
        examples = joinpath(dir, "examples")
        counter = Ref(0)
        downloader = mock_downloader(counter)
        name = only(BENCHMARK_EXAMPLE_NAMES)
        path = ensure_benchmark_example!(examples, name; downloader)
        @test isdir(path)
        @test counter[] == 1
        @test ensure_benchmark_example!(examples, name; downloader) == path
        write(benchmark_example_marker(examples, name), "wrong\n")
        @test_throws ArgumentError ensure_benchmark_example!(examples, name; downloader)
        @test ensure_benchmark_example!(examples, name; refresh = true, downloader) == path
        @test counter[] == 2
    end
    command = worker_command("/tmp/main", "/tmp/case", "/tmp/results/main.json", "main")
    @test occursin("--project=/tmp/main", string(command))
    @test occursin("worker.jl", string(command))
    @test applicable(with_main_worktree, () -> nothing, "main")

    benchmark = Dict(
        :main => Dict(:benchmarks => Dict(stage => Dict(:median_seconds => 2.0, :allocations => 4, :memory_bytes => 8) for stage in Symbol.(BENCHMARK_STAGES))),
        :dirty => Dict(:benchmarks => Dict(stage => Dict(:median_seconds => 1.0, :allocations => 2, :memory_bytes => 4) for stage in Symbol.(BENCHMARK_STAGES))),
    )
    summary = comparison_summary(Dict("example" => benchmark))
    @test summary[:geometric_mean_speedup] == 2.0
    @test summary[:average_allocation_improvement] == 50.0
    @test summary[:average_memory_improvement] == 50.0
    @test percentage_improvement(0, 0) == 0.0
end
end
