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
    scoped_feature = MacroEnergy.tdr_feature_spec(Dict(
        "id" => "availability",
        "field" => "availability",
        "asset" => "VRE",
        "commodity" => "Electricity",
        "weight" => 2.0,
    ))
    merged_features = MacroEnergy.tdr_merge_features([scoped_feature])
    merged_availability = only(filter(feature -> feature.id == "availability", merged_features))
    @test merged_availability.asset == "VRE"
    @test merged_availability.commodity == "Electricity"
    @test merged_availability.user_weight == 2.0

    kmedoids_settings = MacroEnergy.load_tdr_method_settings(Dict(
        "name" => "kmedoids",
        "settings" => Dict("restarts" => 2, "v" => true),
    ))
    @test kmedoids_settings isa MacroEnergy.TDRKMedoidsSettings
    @test kmedoids_settings.restarts == 2
    @test kmedoids_settings.verbose

    mktempdir() do temporary_root
        source_case = joinpath(temporary_root, "source")
        output_case = joinpath(temporary_root, "reduced")
        cp(PREPARE_CASE_TEST_INPUTS, source_case)
        full_length = expand_tdr_fixture!(source_case)
        share_availability_header!(source_case)
        settings_path = joinpath(source_case, "settings", "time_domain_reduction.json")

        settings = MacroEnergy.load_time_domain_reduction_settings(settings_path)
        availability = only(filter(feature -> feature.id == "availability", settings.features))
        @test availability.user_weight == 1.0
        @test settings.method_settings isa MacroEnergy.TDRKMeansSettings
        @test settings.method_settings.restarts == 3
        all_sources, _, _, _, _ = MacroEnergy.tdr_sources(source_case, settings)
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
        excluded_sources, _, _, _, _ = MacroEnergy.tdr_sources(source_case, excluded_settings)
        @test !only(filter(source -> source.header == :solar_pv_MA, excluded_sources)).include_in_clustering

        nested_output_case = joinpath(source_case, "reduced")
        @test_throws ArgumentError preprocess_inputs(source_case, nested_output_case; tdr_settings_path=settings_path)
        @test !ispath(nested_output_case)

        colliding_output_case = joinpath(temporary_root, "previous_output")
        previous_output = joinpath(source_case, basename(colliding_output_case))
        mkpath(previous_output)
        @test_throws ArgumentError preprocess_inputs(source_case, colliding_output_case; tdr_settings_path=settings_path)
        rm(previous_output; recursive=true)

        @test_nowarn preprocess_inputs(source_case, output_case; tdr_settings_path=settings_path)
        @test isfile(joinpath(output_case, "time_domain_reduction_provenance.json"))
        @test_throws ArgumentError preprocess_inputs(source_case, output_case; tdr_settings_path=settings_path)

        reduced_time_data = JSON3.read(read(joinpath(output_case, "system", "time_data.json"), String))
        @test reduced_time_data[:NumberOfSubperiods] == 3
        @test reduced_time_data[:TotalHoursModeled] == full_length
        reduced_map = CSV.read(joinpath(output_case, "system", "period_map.csv"), DataFrame)
        @test nrow(reduced_map) == full_length ÷ PREPARE_CASE_PERIOD_LENGTH
        @test length(unique(reduced_map.Rep_Period_Index)) == 3
        @test nrow(CSV.read(joinpath(output_case, "system", "demand.csv"), DataFrame)) == 3 * PREPARE_CASE_PERIOD_LENGTH

        prepared_case = load_case(output_case)
        @test length(prepared_case.systems) == 1
        case, solution = run_case(output_case; log_to_console=false, log_to_file=false)
        @test length(case.systems) == 1
        @test !isnothing(solution)
        @test_nowarn preprocess_inputs(source_case, output_case; tdr_settings_path=settings_path, overwrite=true)
    end
end
