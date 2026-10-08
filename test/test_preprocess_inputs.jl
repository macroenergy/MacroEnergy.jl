using CSV
using DataFrames
using JSON3
using MacroEnergy
using Test

const PREPARE_CASE_TEST_INPUTS = joinpath(@__DIR__, "test_inputs")
const PREPARE_CASE_PERIOD_LENGTH = 168

function expand_tdr_fixture!(case_path::AbstractString)
    period_map = CSV.read(joinpath(case_path, "system", "Period_map.csv"), DataFrame)
    source_rows = reduce(vcat, [
        collect((period.Rep_Period_Index - 1) * PREPARE_CASE_PERIOD_LENGTH + 1:
                period.Rep_Period_Index * PREPARE_CASE_PERIOD_LENGTH)
        for period in eachrow(period_map)
    ])
    for relative_path in (
        joinpath("system", "demand.csv"),
        joinpath("system", "fuel_prices.csv"),
        joinpath("assets", "availability.csv"),
    )
        path = joinpath(case_path, relative_path)
        data = CSV.read(path, DataFrame)[source_rows, :]
        for name in names(data)
            lowercase(String(name)) in ("time_index", "time", "index", "hour", "datetime") &&
                (data[!, name] = collect(1:nrow(data)))
        end
        CSV.write(path, data)
    end
    time_data_path = joinpath(case_path, "system", "time_data.json")
    time_data = Dict{String,Any}(String(key) => value for (key, value) in pairs(JSON3.read(read(time_data_path, String))))
    time_data["NumberOfSubperiods"] = nrow(period_map)
    time_data["TotalHoursModeled"] = nrow(period_map) * PREPARE_CASE_PERIOD_LENGTH
    delete!(time_data, "SubPeriodMap")
    MacroEnergy.write_json(time_data_path, time_data)
    return nrow(period_map) * PREPARE_CASE_PERIOD_LENGTH
end

function share_availability_header!(case_path::AbstractString)
    path = joinpath(case_path, "assets", "vre.json")
    data = MacroEnergy.mutable_json_data(MacroEnergy.read_json(path))
    data["solar_pv"][1]["instance_data"][2]["edges"]["edge"]["availability"]["timeseries"]["header"] = "solar_pv_MA"
    MacroEnergy.write_json(path, data)
    return nothing
end

@testset "preprocess_inputs" begin
    mktempdir() do temporary_root
        source_case = joinpath(temporary_root, "source")
        output_case = joinpath(temporary_root, "output")
        mkpath.(joinpath.(source_case, ("system", "results", "results_001", "results_example")))
        touch(joinpath(source_case, "system", "time_data.json"))
        MacroEnergy.copy_case(source_case, output_case)
        @test isfile(joinpath(output_case, "system", "time_data.json"))
        @test !isdir(joinpath(output_case, "results"))
        @test !isdir(joinpath(output_case, "results_001"))
        @test !isdir(joinpath(output_case, "results_example"))

        copied_results_case = joinpath(temporary_root, "output_with_results")
        MacroEnergy.copy_case(source_case, copied_results_case; copy_result_files=true)
        @test isdir(joinpath(copied_results_case, "results"))
        @test isdir(joinpath(copied_results_case, "results_001"))
        @test isdir(joinpath(copied_results_case, "results_example"))

        output_features_directory = joinpath(source_case, "TDR", "output_features")
        mkpath(output_features_directory)
        touch(joinpath(output_features_directory, "output_features.csv.gz"))
        touch(joinpath(output_features_directory, "output_metadata.json"))
        MacroEnergy.copy_case(source_case, output_case; overwrite=true)
        @test isfile(joinpath(output_features_directory, "output_features.csv.gz"))
        @test isfile(joinpath(output_features_directory, "output_metadata.json"))
        @test !isdir(joinpath(output_case, "TDR"))

    end

    mktempdir() do temporary_root
        source_case = joinpath(temporary_root, "source")
        output_case = joinpath(temporary_root, "reduced")
        cp(PREPARE_CASE_TEST_INPUTS, source_case)
        full_length = expand_tdr_fixture!(source_case)
        share_availability_header!(source_case)
        MacroEnergy.write_json(joinpath(source_case, "preprocess_log.json"), Dict("stale" => true))
        settings_path = joinpath(source_case, "settings", "time_domain_reduction.json")

        settings = MacroEnergy.load_time_domain_reduction_settings(settings_path)
        availability = only(filter(feature -> feature.id == "availability", settings.features))
        @test availability.user_weight == 1.0
        @test settings.method_settings isa MacroEnergy.TDRKMeansSettings
        @test settings.method_settings.restarts == 3
        all_sources = only(MacroEnergy.tdr_prepare_inputs(source_case, [settings]).systems).sources
        @test [source.key for source in all_sources] == sort([source.key for source in all_sources])
        shared_availability = only(filter(source -> source.header == :solar_pv_MA, all_sources))
        @test shared_availability.occurrences == 2
        @test shared_availability.weight == 2.0

        excluded_settings_path = joinpath(temporary_root, "excluded.json")
        MacroEnergy.write_json(excluded_settings_path, Dict(
            "timesteps_per_representative_period" => 168,
            "representative_periods" => 3,
            "method" => Dict("name" => "kmeans", "settings" => Dict("restarts" => 1)),
            "scaling" => "standardize",
            "exclude" => [Dict("id" => "availability")],
        ))
        excluded_settings = MacroEnergy.load_time_domain_reduction_settings(excluded_settings_path)
        @test !any(feature -> feature.id == "availability", excluded_settings.features)
        excluded_sources = only(MacroEnergy.tdr_prepare_inputs(source_case, [excluded_settings]).systems).sources
        @test !only(filter(source -> source.header == :solar_pv_MA, excluded_sources)).include_in_clustering

        output_settings_path = joinpath(temporary_root, "output_features.json")
        MacroEnergy.write_json(output_settings_path, Dict(
            "timesteps_per_representative_period" => 168,
            "representative_periods" => 3,
            "method" => Dict("name" => "kmeans", "settings" => Dict("restarts" => 1)),
            "scaling" => "standardize",
            "output_based_features" => Dict(
                "weight" => 0.5,
                "features" => [Dict("provider" => "flow")],
                "subperiod_runs" => Dict(
                    "exclude_policy_constraints" => true,
                    "save_subperiod_inputs" => true,
                    "save_subperiod_results" => true,
                ),
            ),
        ))
        output_settings = MacroEnergy.load_time_domain_reduction_settings(output_settings_path)
        subperiod_case = joinpath(temporary_root, "subperiod_case")
        MacroEnergy.tdr_materialize_subperiod_case!(
            MacroEnergy.tdr_prepare_subperiod_inputs(only(MacroEnergy.tdr_prepare_inputs(source_case, [output_settings]).systems)),
            subperiod_case, 2, output_settings)
        subperiod_time_data = JSON3.read(read(joinpath(subperiod_case, "system", "time_data.json"), String))
        @test subperiod_time_data[:NumberOfSubperiods] == 1
        @test !haskey(subperiod_time_data, :SubPeriodMap)
        @test nrow(CSV.read(joinpath(subperiod_case, "system", "demand.csv"), DataFrame)) == 168
        subperiod_nodes = MacroEnergy.mutable_json_data(MacroEnergy.read_json(joinpath(subperiod_case, "system", "nodes.json")))
        @test !occursin("CO2CapConstraint", string(subperiod_nodes))
        result_path = MacroEnergy.tdr_save_subperiod_results!(
            source_case,
            2,
            Dict("output:flow:test" => [(output_settings.output_features.features[1], [1.0, 2.0])]),
        )
        @test isfile(result_path)
        @test MacroEnergy.read_json(result_path)["period"] == 2

        nested_output_case = joinpath(source_case, "reduced")
        @test_throws ArgumentError preprocess_inputs(source_case, nested_output_case; tdr_settings_path=settings_path)
        @test !ispath(nested_output_case)

        colliding_output_case = joinpath(temporary_root, "previous_output")
        previous_output = joinpath(source_case, basename(colliding_output_case))
        mkpath(previous_output)
        @test_throws ArgumentError preprocess_inputs(source_case, colliding_output_case; tdr_settings_path=settings_path)
        rm(previous_output; recursive=true)

        @test preprocess_inputs(source_case, output_case; tdr_settings_path=settings_path) === nothing
        @test isfile(joinpath(output_case, "preprocessing_logs", "time_domain_reduction_provenance.json"))
        @test isfile(joinpath(output_case, "preprocessing_logs", "preprocess_log.json"))
        @test !isfile(joinpath(output_case, "preprocess_log.json"))
        @test !isfile(joinpath(output_case, "time_domain_reduction_provenance.json"))
        @test_throws ArgumentError preprocess_inputs(source_case, output_case; tdr_settings_path=settings_path)

        reduced_time_data = JSON3.read(read(joinpath(output_case, "system", "time_data.json"), String))
        @test reduced_time_data[:NumberOfSubperiods] == 3
        @test reduced_time_data[:TotalHoursModeled] == full_length
        reduced_map = CSV.read(joinpath(output_case, "system", "period_map.csv"), DataFrame)
        @test nrow(reduced_map) == full_length ÷ PREPARE_CASE_PERIOD_LENGTH
        @test length(unique(reduced_map.Rep_Period_Index)) == 3
        @test nrow(CSV.read(joinpath(output_case, "system", "demand.csv"), DataFrame)) == 3 * PREPARE_CASE_PERIOD_LENGTH
        provenance = JSON3.read(read(joinpath(output_case, "preprocessing_logs", "time_domain_reduction_provenance.json"), String))
        @test length(provenance[:forced_extreme_periods]) == 1
        @test only(provenance[:forced_extreme_periods]) in provenance[:representative_periods]
        preprocess_log = JSON3.read(read(joinpath(output_case, "preprocessing_logs", "preprocess_log.json"), String))
        @test !haskey(preprocess_log, :stale)
        tdr_log = preprocess_log[:time_domain_reduction]
        @test tdr_log[:temporal_summary][:original_hours] == full_length
        @test tdr_log[:temporal_summary][:trailing_source_hours_excluded_from_tdr] == 0
        @test tdr_log[:clustering][:regular_representative_periods] == 2
        @test tdr_log[:clustering_features][:unique_time_series] > 0
        @test !isempty(tdr_log[:clustering_features][:sources])
        @test length(tdr_log[:extreme_periods]) == 1
        first_representative = first(tdr_log[:representative_periods])
        @test first_representative[:total_mapped_periods] == length(first_representative[:mapped_periods])

        prepared_case = load_case(output_case)
        @test length(prepared_case.systems) == 1
        # Local runners may supply another optimizer without adding a test dependency.
        solver_kwargs = @isdefined(PREPROCESS_TEST_RUN_KWARGS) ? PREPROCESS_TEST_RUN_KWARGS : NamedTuple()
        case, solution = run_case(output_case; log_to_console=false, log_to_file=false, solver_kwargs...)
        @test length(case.systems) == 1
        @test !isnothing(solution)
        @test preprocess_inputs(source_case, output_case; tdr_settings_path=settings_path, overwrite=true) === nothing
    end

    @testset "multi-System output subperiod inputs" begin
        mktempdir() do temporary_root
            source_case = joinpath(temporary_root, "source")
            cp(PREPARE_CASE_TEST_INPUTS, source_case)
            expand_tdr_fixture!(source_case)
            system = MacroEnergy.mutable_json_data(MacroEnergy.read_json(joinpath(source_case, "system_data.json")))
            MacroEnergy.write_json(joinpath(source_case, "system_data.json"), Dict(
                "case" => Any[system, deepcopy(system)],
                "settings" => Dict("path" => "settings/case_settings.json"),
            ))
            case_settings = MacroEnergy.mutable_json_data(MacroEnergy.read_json(
                joinpath(source_case, "settings", "case_settings.json"),
            ))
            case_settings["PeriodLengths"] = Any[1, 1]
            MacroEnergy.write_json(joinpath(source_case, "settings", "case_settings.json"), case_settings)

            MacroEnergy.write_json(joinpath(temporary_root, "output_features.json"), Dict(
                "timesteps_per_representative_period" => 168,
                "representative_periods" => 3,
                "method" => Dict("name" => "kmeans"),
                "scaling" => "standardize",
                "output_based_features" => Dict(
                    "weight" => 0.5,
                    "features" => [Dict("provider" => "flow")],
                ),
            ))
            output_settings = MacroEnergy.load_time_domain_reduction_settings(joinpath(
                temporary_root, "output_features.json",
            ))
            prepared = MacroEnergy.tdr_prepare_inputs(source_case, [output_settings, output_settings])
            @test length(MacroEnergy.tdr_prepare_system_inputs!(source_case, prepared).systems) == 2
            prepared_system_data = MacroEnergy.read_json(joinpath(source_case, "system_data.json"))
            @test startswith(prepared_system_data["case"][1]["time_data"]["path"], "inputs/system_1/system/")
            @test prepared_system_data["case"][2]["assets"]["path"] == "inputs/system_2/assets"
            subperiod_case = joinpath(temporary_root, "system_2_period_1")
            MacroEnergy.tdr_materialize_subperiod_case!(
                MacroEnergy.tdr_prepare_subperiod_inputs(MacroEnergy.tdr_prepare_inputs(source_case,
                    [output_settings, output_settings]).systems[2]),
                subperiod_case,
                1,
                output_settings,
            )
            isolated_case_settings = MacroEnergy.read_json(joinpath(
                subperiod_case, "settings", "case_settings.json",
            ))
            @test isolated_case_settings["PeriodLengths"] == [1]
            @test isolated_case_settings["ExpansionHorizon"] == "PerfectForesight"
            isolated_case = load_case(subperiod_case)
            @test length(isolated_case.systems) == 1
            @test !isdir(MacroEnergy.tdr_output_features_directory(source_case; system_index=2))
            @test MacroEnergy.tdr_saved_subperiod_directory(source_case, 1; system_index=2) ==
                joinpath(source_case, "TDR", "subperiod_solves", "system_2", "subperiod_0001")
        end
    end
end

include("test_tdr_settings.jl")
include("test_tdr_clustering.jl")
include("test_tdr_system_inputs.jl")
include("test_tdr_csv_inputs.jl")
include("test_tdr_inline_inputs.jl")
include("test_tdr_features.jl")
include("test_tdr_output_feature_cache.jl")
include("test_tdr_candidate_periods.jl")
