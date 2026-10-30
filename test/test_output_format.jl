module TestOutputFormat

using Test
using HiGHS
using JuMP
using CSV, DataFrames, JSON3
using DuckDB
import DBInterface
import MacroEnergy:
    check_myopic_capacity_outputs,
    configure_settings,
    duckdb_read,
    empty_system,
    find_output_file,
    get_output_format,
    get_output_significant_digits,
    load_previous_capacity_results,
    output_enabled,
    output_file,
    round_float_columns!,
    run_case,
    write_dataframe

include("utilities.jl")

const test_path = joinpath(@__DIR__, "test_small_case")

# Covers the column types Macro outputs use: Symbol labels (with and without missing values),
# integer time steps, and float values (with and without missing values)
sample_df() = DataFrame(
    commodity = [:Electricity, :Electricity, :NaturalGas],
    zone = Union{Missing,Symbol}[:z1, missing, :z2],
    time = [1, 2, 3],
    value = [0.1234567891234, -2.0e-13, 12345.678901],
    price = Union{Missing,Float64}[1.0, missing, 3.3333333333],
)

function parquet_codecs(path::AbstractString)
    db = DBInterface.connect(DuckDB.DB, ":memory:")
    try
        result = DuckDB.query(db, "SELECT DISTINCT compression FROM parquet_metadata('$path')")
        return DataFrame(result).compression
    finally
        DBInterface.close!(db)
    end
end

# Copy the small test case into `dir`, without its reference results, and apply the given settings
function copy_small_case(dir::AbstractString; macro_settings::AbstractDict, case_settings=nothing, num_periods::Int=1)
    case_dir = joinpath(mkpath(dir), "case")
    cp(test_path, case_dir)
    rm(joinpath(case_dir, "results"); recursive=true, force=true)
    write(joinpath(case_dir, "settings", "macro_settings.json"), JSON3.write(macro_settings))
    if !isnothing(case_settings)
        write(joinpath(case_dir, "settings", "case_settings.json"), JSON3.write(case_settings))
    end
    if num_periods > 1
        system_data = JSON3.read(read(joinpath(case_dir, "system_data.json"), String), Dict{String,Any})
        system_data["case"] = fill(only(system_data["case"]), num_periods)
        write(joinpath(case_dir, "system_data.json"), JSON3.write(system_data))
    end
    return case_dir
end

function run_small_case(case_dir::AbstractString)
    return @warn_error_logger run_case(
        case_dir; log_to_console=false, log_to_file=false, write_status=false,
        optimizer=HiGHS.Optimizer, optimizer_attributes=()
    )
end

output_basenames(dir) = sort([first(split(f, '.')) for f in readdir(dir) if isfile(joinpath(dir, f))])

function test_output_format()
    @testset "Output format settings" begin
        settings = configure_settings(NamedTuple())
        @test settings.OutputFormat == "csv"
        @test settings.WriteOutputs == NamedTuple()
        @test isnothing(settings.OutputSignificantDigits)

        @test configure_settings((OutputFormat="parquet",)).OutputFormat == "parquet"
        @test configure_settings((OutputFormat=(Flow="parquet", Capacity="csv.gz"),)).OutputFormat.Capacity == "csv.gz"
        @test configure_settings((WriteOutputs=(Curtailment=false,),)).WriteOutputs.Curtailment == false
        @test configure_settings((OutputSignificantDigits=6,)).OutputSignificantDigits == 6

        @test_throws AssertionError configure_settings((OutputFormat="xlsx",))
        @test_throws AssertionError configure_settings((OutputFormat=(Flows="parquet",),))
        @test_throws AssertionError configure_settings((OutputFormat=(Flow="xlsx",),))
        @test_throws AssertionError configure_settings((WriteOutputs=(Flow="no",),))
        @test_throws AssertionError configure_settings((WriteOutputs=(Flows=false,),))
        @test configure_settings((WriteOutputs=(Duals=false,),)).WriteOutputs.Duals == false
        @test_throws AssertionError configure_settings((OutputSignificantDigits=0,))
        @test_throws AssertionError configure_settings((OutputSignificantDigits=2.5,))
    end

    @testset "DualExportsEnabled is deprecated" begin
        # Not set: no warning, and duals are written. DualExportsEnabled still reads as a Bool
        # mirroring WriteOutputs.Duals, for code that reads it
        settings = @test_logs configure_settings(NamedTuple())
        @test settings.DualExportsEnabled === true
        settings = @test_logs configure_settings((WriteOutputs=(Duals=false,),))
        @test settings.DualExportsEnabled === false

        # Translated into WriteOutputs.Duals, with a deprecation warning
        settings = @test_logs (:warn, r"DualExportsEnabled is deprecated") configure_settings((DualExportsEnabled=false,))
        @test settings.WriteOutputs.Duals == false
        @test settings.DualExportsEnabled === false
        system = empty_system(test_path)
        system.settings = settings
        @test !output_enabled(system, :Duals)

        # Both set: fine if they agree, an error if they don't
        settings = @test_logs (:warn,) configure_settings((DualExportsEnabled=true, WriteOutputs=(Duals=true,)))
        @test settings.WriteOutputs.Duals == true
        @test_throws ErrorException configure_settings((DualExportsEnabled=true, WriteOutputs=(Duals=false,)))
        @test_throws AssertionError configure_settings((DualExportsEnabled="yes",))
    end

    @testset "Myopic runs must write capacity to be continued" begin
        system_with(settings) = (system = empty_system(test_path); system.settings = configure_settings(settings); system)
        on = system_with(NamedTuple())
        off = system_with((WriteOutputs=(Capacity=false,),))
        myopic(; stop=Inf, restart=false, from=1) =
            (StopAfterPeriod=stop, Restart=(enabled=restart, folder="results_001", from_period=from))

        # Stopping early means the run will be continued: missing capacity outputs are an error
        @test_throws r"stops after period 2 of 3" check_myopic_capacity_outputs([on, off, on], myopic(stop=2))
        # Periods after StopAfterPeriod are not written, so they don't matter
        @test_logs check_myopic_capacity_outputs([on, on, off], myopic(stop=2))
        # A full run only warns
        @test_logs (:warn, r"cannot be used to restart") check_myopic_capacity_outputs([on, off, on], myopic())
        # A restarted run does not write the periods before from_period
        @test_logs check_myopic_capacity_outputs([off, on, on], myopic(restart=true, from=2))
    end

    @testset "Output format helpers" begin
        system = empty_system(test_path)

        system.settings = configure_settings((OutputFormat="parquet",))
        @test get_output_format(system, :Flow) == "parquet"
        @test output_file("dir", "flows", system, :Flow) == joinpath("dir", "flows.parquet")

        system.settings = configure_settings((
            OutputFormat=(Flow="csv.gz",),
            WriteOutputs=(Curtailment=false,),
            OutputSignificantDigits=4,
        ))
        @test get_output_format(system, :Flow) == "csv.gz"
        @test get_output_format(system, :Capacity) == "csv"
        @test !output_enabled(system, :Curtailment)
        @test output_enabled(system, :Flow)
        @test get_output_significant_digits(system) == 4

        # Settings built by hand without the output keys fall back to the defaults
        system.settings = (OutputLayout="long",)
        @test get_output_format(system, :Flow) == "csv"
        @test output_enabled(system, :Flow)
        @test isnothing(get_output_significant_digits(system))

        mktempdir() do dir
            @test_throws ErrorException find_output_file(dir, "capacity")
            touch(joinpath(dir, "capacity.parquet"))
            @test find_output_file(dir, "capacity") == joinpath(dir, "capacity.parquet")
            touch(joinpath(dir, "capacity.csv"))
            @test find_output_file(dir, "capacity") == joinpath(dir, "capacity.csv")
        end
    end

    @testset "write_dataframe round-trip" begin
        mktempdir() do dir
            ref = sample_df()
            for ext in ("csv", "csv.gz", "parquet")
                path = joinpath(dir, "table.$ext")
                write_dataframe(path, sample_df())
                df = duckdb_read(path)
                @test names(df) == names(ref)
                @test string.(df.commodity) == string.(ref.commodity)
                @test isequal(passmissing(string).(df.zone), passmissing(string).(ref.zone))
                @test df.time == ref.time
                @test df.value == ref.value
                @test isequal(df.price, ref.price)
            end
            @test parquet_codecs(joinpath(dir, "table.parquet")) == ["ZSTD"]
        end
    end

    @testset "Significant digit rounding" begin
        df = sample_df()
        round_float_columns!(df, 3)
        @test df.value == [0.123, -2.0e-13, 12300.0]
        @test isequal(df.price, [1.0, missing, 3.33])
        @test df.time == [1, 2, 3]
        @test df.commodity == sample_df().commodity

        # Columns are replaced, not modified in place
        values = [1.23456]
        round_float_columns!(DataFrame(x=values; copycols=false), 2)
        @test values == [1.23456]

        mktempdir() do dir
            write_dataframe(joinpath(dir, "rounded.csv"), sample_df(); sigdigits=3)
            @test CSV.read(joinpath(dir, "rounded.csv"), DataFrame).value == [0.123, -2.0e-13, 12300.0]
            write_dataframe(joinpath(dir, "exact.csv"), sample_df())
            @test CSV.read(joinpath(dir, "exact.csv"), DataFrame).value == sample_df().value
        end
    end

    @testset "Myopic restart reads any capacity format" begin
        mktempdir() do dir
            capacity = DataFrame(
                component_id=["a", "b"], capacity=[10.5, 2.0],
                new_capacity=[0.5, 0.0], retired_capacity=[0.0, 1.0],
            )
            for ext in ("csv", "csv.gz", "parquet")
                period_dir = mkpath(joinpath(dir, ext, "results_period_1"))
                write_dataframe(joinpath(period_dir, "capacity.$ext"), copy(capacity))
                df = load_previous_capacity_results(find_output_file(period_dir, "capacity"))
                @test string.(df.component_id) == capacity.component_id
                @test df.capacity == capacity.capacity
                @test df.new_capacity == capacity.new_capacity
                @test df.retired_capacity == capacity.retired_capacity
            end
        end
    end

    @testset "run_case with per-output formats and switches" begin
        mktempdir() do dir
            default_dir = copy_small_case(joinpath(dir, "default");
                macro_settings=Dict("ConstraintScaling" => true, "OutputLayout" => "long"))
            compact_dir = copy_small_case(joinpath(dir, "compact");
                macro_settings=Dict(
                    "ConstraintScaling" => true,
                    "OutputLayout" => "long",
                    "OutputFormat" => Dict("Flow" => "parquet", "StorageLevel" => "csv.gz"),
                    "WriteOutputs" => Dict("Curtailment" => false),
                ))
            run_small_case(default_dir)
            run_small_case(compact_dir)

            default_results = joinpath(default_dir, "results_001", "results")
            compact_results = joinpath(compact_dir, "results_001", "results")

            @test isfile(joinpath(default_results, "flows.csv"))
            @test isfile(joinpath(default_results, "curtailment.csv"))
            @test isfile(joinpath(compact_results, "flows.parquet"))
            @test isfile(joinpath(compact_results, "storage_level.csv.gz"))
            @test isfile(joinpath(compact_results, "capacity.csv"))
            @test !any(startswith("curtailment"), readdir(compact_results))
            # Same tables as the default run, except the switched-off curtailment
            @test output_basenames(compact_results) == filter(!=("curtailment"), output_basenames(default_results))

            default_flows = sort(duckdb_read(joinpath(default_results, "flows.csv")), [:component_id, :time])
            compact_flows = sort(duckdb_read(joinpath(compact_results, "flows.parquet")), [:component_id, :time])
            @test nrow(compact_flows) == nrow(default_flows)
            @test string.(compact_flows.component_id) == string.(default_flows.component_id)
            @test isapprox(compact_flows.value, default_flows.value; atol=1e-6)

            default_storage = duckdb_read(joinpath(default_results, "storage_level.csv"))
            compact_storage = duckdb_read(joinpath(compact_results, "storage_level.csv.gz"))
            @test nrow(compact_storage) == nrow(default_storage)
        end
    end

    @testset "Myopic run and restart with parquet outputs" begin
        mktempdir() do dir
            macro_settings = Dict(
                "ConstraintScaling" => true,
                "OutputLayout" => "wide",
                "OutputFormat" => "parquet",
                "OutputSignificantDigits" => 6,
            )
            myopic = Dict("SolutionAlgorithm" => "Monolithic", "ExpansionHorizon" => "Myopic", "PeriodLengths" => [5, 5])
            case_dir = copy_small_case(dir; macro_settings, case_settings=myopic, num_periods=2)
            run_small_case(case_dir)

            first_run = joinpath(case_dir, "results_001")
            @test isfile(joinpath(first_run, "capacity_summary.parquet"))
            for period_idx in 1:2
                period_dir = joinpath(first_run, "results_period_$period_idx")
                @test isfile(joinpath(period_dir, "capacity.parquet"))
                @test isfile(joinpath(period_dir, "flows.parquet"))
                @test !any(endswith(".csv"), filter(!=("objective_value.csv"), readdir(period_dir)))
            end

            # Restart from period 2, reading period 1's capacity.parquet
            restart = merge(myopic, Dict("MyopicSettings" => Dict(
                "Restart" => Dict("enabled" => true, "folder" => "results_001", "from_period" => 2),
            )))
            write(joinpath(case_dir, "settings", "case_settings.json"), JSON3.write(restart))
            run_small_case(case_dir)

            restarted = joinpath(case_dir, "results_002", "results_period_2")
            original = joinpath(first_run, "results_period_2")
            @test CSV.read(joinpath(restarted, "objective_value.csv"), DataFrame).objective_value ≈
                  CSV.read(joinpath(original, "objective_value.csv"), DataFrame).objective_value
            restarted_capacity = sort(duckdb_read(joinpath(restarted, "capacity.parquet")), :component_id)
            original_capacity = sort(duckdb_read(joinpath(original, "capacity.parquet")), :component_id)
            @test isapprox(restarted_capacity.capacity, original_capacity.capacity; rtol=1e-6)
        end
    end

    @testset "Myopic restart from a folder without capacity files" begin
        mktempdir() do dir
            restart = Dict(
                "SolutionAlgorithm" => "Monolithic", "ExpansionHorizon" => "Myopic", "PeriodLengths" => [5, 5],
                "MyopicSettings" => Dict("Restart" => Dict("enabled" => true, "folder" => "results_001", "from_period" => 2)),
            )
            case_dir = copy_small_case(dir; macro_settings=Dict("ConstraintScaling" => true), case_settings=restart, num_periods=2)
            mkpath(joinpath(case_dir, "results_001", "results_period_1"))
            # Fails while loading the restart capacities, before any solve
            @test_throws r"WriteOutputs.Capacity = false" run_small_case(case_dir)
        end
    end
end

test_output_format()

end # module TestOutputFormat
