module TestOutputFormat

using Test
using HiGHS
using JuMP
using CSV, DataFrames, JSON3
using DuckDB
import DBInterface
import MacroEnergy:
    InputValidationError,
    check_myopic_capacity_outputs,
    configure_settings,
    duckdb_read,
    empty_system,
    find_output_file,
    get_output_format,
    get_output_layout,
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

# Copy the small test case into `dir`, without its reference results, with `settings` as its
# case_settings.json. The small case itself keeps the deprecated per-period macro_settings.json.
function copy_small_case(dir::AbstractString; settings::AbstractDict, num_periods::Int=1)
    case_dir = joinpath(mkpath(dir), "case")
    cp(test_path, case_dir)
    rm(joinpath(case_dir, "results"); recursive=true, force=true)
    rm(joinpath(case_dir, "settings", "macro_settings.json"))
    write(joinpath(case_dir, "settings", "case_settings.json"), JSON3.write(settings))
    system_data = JSON3.read(read(joinpath(case_dir, "system_data.json"), String), Dict{String,Any})
    period = only(system_data["case"])
    delete!(period, "settings")
    system_data["case"] = fill(period, num_periods)
    write(joinpath(case_dir, "system_data.json"), JSON3.write(system_data))
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
    @testset "Output settings" begin
        settings = configure_settings(NamedTuple()).OutputSettings
        @test settings.Format == "csv"
        @test settings.Write == NamedTuple()
        @test isnothing(settings.SignificantDigits)

        output_settings(; kwargs...) = configure_settings((OutputSettings=(; kwargs...),)).OutputSettings
        @test output_settings(Format="parquet").Format == "parquet"
        @test output_settings(Format=(Flow="parquet", Capacity="csv.gz")).Format.Capacity == "csv.gz"
        @test output_settings(Write=(Curtailment=false,)).Write.Curtailment == false
        @test output_settings(Write=(Duals=false,)).Write.Duals == false
        @test output_settings(Write=(FullTimeseries=true,)).Write.FullTimeseries == true
        @test output_settings(SignificantDigits=6).SignificantDigits == 6
        # Keys that are not given keep their defaults
        @test output_settings(Dir="out").Format == "csv"

        @test_throws InputValidationError output_settings(Format="xlsx")
        @test_throws InputValidationError output_settings(Format=(Flows="parquet",))
        @test_throws InputValidationError output_settings(Format=(Flow="xlsx",))
        @test_throws InputValidationError output_settings(Write=(Flow="no",))
        @test_throws InputValidationError output_settings(Write=(Flows=false,))
        @test_throws InputValidationError output_settings(SignificantDigits=0)
        @test_throws InputValidationError output_settings(SignificantDigits=2.5)
        @test_throws InputValidationError output_settings(Dirr="out")
    end

    @testset "Deprecated output settings" begin
        # No deprecated keys: no warning
        @test_logs configure_settings(NamedTuple())
        @test_logs configure_settings((OutputSettings=(Write=(Duals=false,),),))

        # Every old name is translated, with a deprecation warning
        settings = @test_logs (:warn, r"deprecated") configure_settings((
            OutputDir="out", OverwriteResults=true, OutputFormat="parquet", OutputLayout="wide",
            WriteOutputs=(Curtailment=false,), OutputSignificantDigits=4, OutputAssetTags=false,
            WriteFullTimeseries=true, DualExportsEnabled=false,
        ))
        @test settings.OutputSettings == (Dir="out", Overwrite=true, Format="parquet", Layout="wide",
            Write=(Curtailment=false, FullTimeseries=true, Duals=false), SignificantDigits=4, AssetTags=false)
        @test !haskey(settings, :OutputDir)
        system = empty_system(test_path)
        system.settings = settings
        @test !output_enabled(system, :Duals)
        @test output_enabled(system, :FullTimeseries)

        # Old and new name both set: fine if they agree, an error if they don't
        settings = @test_logs (:warn,) configure_settings((DualExportsEnabled=true, OutputSettings=(Write=(Duals=true,),)))
        @test settings.OutputSettings.Write.Duals == true
        @test_throws InputValidationError configure_settings((DualExportsEnabled=true, OutputSettings=(Write=(Duals=false,),)))
        @test_throws InputValidationError configure_settings((OutputDir="a", OutputSettings=(Dir="b",)))
        # Translated values are validated like any other
        @test_throws InputValidationError configure_settings((DualExportsEnabled="yes",))
    end

    @testset "Myopic runs must write capacity to be continued" begin
        system_with(settings) = (system = empty_system(test_path); system.settings = configure_settings(settings); system)
        on = system_with(NamedTuple())
        off = system_with((OutputSettings=(Write=(Capacity=false,),),))
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

        system.settings = configure_settings((OutputSettings=(Format="parquet",),))
        @test get_output_format(system, :Flow) == "parquet"
        @test output_file("dir", "flows", system, :Flow) == joinpath("dir", "flows.parquet")

        system.settings = configure_settings((OutputSettings=(
            Format=(Flow="csv.gz",),
            Write=(Curtailment=false,),
            SignificantDigits=4,
        ),))
        @test get_output_format(system, :Flow) == "csv.gz"
        @test get_output_format(system, :Capacity) == "csv"
        @test !output_enabled(system, :Curtailment)
        @test output_enabled(system, :Flow)
        @test get_output_significant_digits(system) == 4
        # The one output that is off unless switched on
        @test !output_enabled(system, :FullTimeseries)

        # Settings built by hand without the output keys fall back to the defaults
        for settings in ((OutputSettings=(Layout="long",),), (ConstraintScaling=false,))
            system.settings = settings
            @test get_output_format(system, :Flow) == "csv"
            @test output_enabled(system, :Flow)
            @test !output_enabled(system, :FullTimeseries)
            @test isnothing(get_output_significant_digits(system))
        end

        # Old names set from Julia are an error, rather than silently ignored
        system.settings = merge(configure_settings(NamedTuple()), (OutputLayout="wide",))
        @test_throws r"system.settings.OutputLayout: is no longer used" get_output_layout(system, :Flow)
        system.settings = merge(configure_settings(NamedTuple()), (OverwriteResults=true,))
        @test_throws r"Set system.settings.OutputSettings.Overwrite instead" output_enabled(system, :Flow)

        mktempdir() do dir
            @test_throws ErrorException find_output_file(dir, "capacity")
            touch(joinpath(dir, "capacity.parquet"))
            @test find_output_file(dir, "capacity") == joinpath(dir, "capacity.parquet")
            # A second format is a leftover from an earlier run: refuse to guess which is current
            touch(joinpath(dir, "capacity.csv"))
            @test_throws r"more than one output file" find_output_file(dir, "capacity")
            rm(joinpath(dir, "capacity.parquet"))
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
                # The apostrophe checks that DuckDB reads paths that need SQL quoting
                period_dir = mkpath(joinpath(dir, "O'Brien", ext, "results_period_1"))
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
                settings=Dict("ConstraintScaling" => true, "OutputSettings" => Dict("Layout" => "long")))
            compact_dir = copy_small_case(joinpath(dir, "compact");
                settings=Dict(
                    "ConstraintScaling" => true,
                    "OutputSettings" => Dict(
                        "Layout" => "long",
                        "Format" => Dict("Flow" => "parquet", "StorageLevel" => "csv.gz"),
                        "Write" => Dict("Curtailment" => false),
                    ),
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
            settings = Dict(
                "SolutionAlgorithm" => "Monolithic", "ExpansionHorizon" => "Myopic", "PeriodLengths" => [5, 5],
                "ConstraintScaling" => true,
                "OutputSettings" => Dict("Layout" => "wide", "Format" => "parquet", "SignificantDigits" => 6),
            )
            # A case folder with an apostrophe: the restart reads capacity.parquet through DuckDB SQL
            case_dir = copy_small_case(joinpath(dir, "O'Brien"); settings, num_periods=2)
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
            restart = merge(settings, Dict("MyopicSettings" => Dict(
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
                "ConstraintScaling" => true,
                "MyopicSettings" => Dict("Restart" => Dict("enabled" => true, "folder" => "results_001", "from_period" => 2)),
            )
            case_dir = copy_small_case(dir; settings=restart, num_periods=2)
            mkpath(joinpath(case_dir, "results_001", "results_period_1"))
            # Fails while loading the restart capacities, before any solve
            @test_throws r"OutputSettings.Write.Capacity = false" run_small_case(case_dir)
        end
    end

    @testset "One settings file and deprecated per-period files give the same results" begin
        mktempdir() do dir
            # The small case as it is, with the settings of its macro_settings.json
            legacy_dir = joinpath(mkpath(joinpath(dir, "legacy")), "case")
            cp(test_path, legacy_dir)
            rm(joinpath(legacy_dir, "results"); recursive=true, force=true)
            unified_dir = copy_small_case(joinpath(dir, "unified"); settings=Dict(
                "SolutionAlgorithm" => "Monolithic",
                "ConstraintScaling" => true,
                "OutputSettings" => Dict("Layout" => "wide"),
            ))
            run_small_case(legacy_dir)
            run_small_case(unified_dir)

            legacy_results = joinpath(legacy_dir, "results_001", "results")
            unified_results = joinpath(unified_dir, "results_001", "results")
            @test sort(readdir(unified_results)) == sort(readdir(legacy_results))
            objective(results) = CSV.read(joinpath(results, "objective_value.csv"), DataFrame).objective_value
            @test objective(unified_results) ≈ objective(legacy_results)
        end
    end
end

test_output_format()

end # module TestOutputFormat
