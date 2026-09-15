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
    @testset "TDR input-path traversal" begin
        input_data = Dict(
            "input" => Dict("path" => "inputs/time_data.json"),
            "profile" => Dict("timeseries" => Dict(
                "path" => "data/availability.csv",
                "header" => "availability",
            )),
            "nested" => Any[Dict("path" => "assets")],
        )
        paths = String[]
        MacroEnergy.tdr_visit_input_paths!(path -> push!(paths, path), input_data)
        @test Set(paths) == Set((
            "inputs/time_data.json",
            "data/availability.csv",
            "assets",
        ))

        empty!(paths)
        MacroEnergy.tdr_visit_input_paths!(path -> push!(paths, path), input_data;
            include_timeseries=false,
            stop_at_timeseries=true,
        )
        @test Set(paths) == Set(("inputs/time_data.json", "assets"))

        sources = Dict{String,MacroEnergy.TimeSeriesSource}()
        MacroEnergy.tdr_collect_references!(
            sources,
            Dict(
                "availability" => collect(1:4),
                "nested" => Dict("availability" => collect(5:8)),
            ),
            "asset.json",
            ".",
            4,
            4,
            Ref(0),
            [MacroEnergy.TDRFeatureSpec(field="availability")],
            MacroEnergy.TDRFeatureSpec[],
            Set{String}(),
        )
        @test Set(Tuple(source.inline_path) for source in values(sources)) == Set((
            ("availability",),
            ("nested", "availability"),
        ))
        @test Set(Tuple(first(source.references).input_path) for source in values(sources)) == Set((
            ("availability",),
            ("nested", "availability"),
        ))

        mktempdir() do case_root
            mkpath.(joinpath.(case_root, ("inputs", "assets", "data")))
            MacroEnergy.write_json(joinpath(case_root, "system_data.json"), Dict(
                "time_data" => Dict("path" => "inputs/time_data.json"),
                "assets" => Dict("path" => "assets"),
            ))
            MacroEnergy.write_json(joinpath(case_root, "inputs", "time_data.json"), Dict())
            MacroEnergy.write_json(joinpath(case_root, "assets", "asset.json"), Dict(
                "availability" => Dict("timeseries" => Dict(
                    "path" => "data/availability.csv",
                    "header" => "availability",
                )),
                "nested_input" => Dict("path" => "inputs/nested.json"),
            ))
            MacroEnergy.write_json(joinpath(case_root, "inputs", "nested.json"), Dict())
            touch(joinpath(case_root, "data", "availability.csv"))
            touch(joinpath(case_root, "notes.md"))

            json_files = Set(MacroEnergy.tdr_input_json_files(case_root))
            @test json_files == Set(abspath.([
                joinpath(case_root, "system_data.json"),
                joinpath(case_root, "inputs", "time_data.json"),
                joinpath(case_root, "assets", "asset.json"),
                joinpath(case_root, "inputs", "nested.json"),
            ]))

            manifest = Set(MacroEnergy.tdr_case_input_manifest(case_root))
            @test joinpath(case_root, "data", "availability.csv") in manifest
            @test joinpath(case_root, "notes.md") in manifest
            @test all(ispath, manifest)
        end
    end

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

        output_features_directory = joinpath(output_case, "TDR", "output_features")
        mkpath(output_features_directory)
        touch(joinpath(output_features_directory, "output_features.csv.gz"))
        touch(joinpath(output_features_directory, "output_metadata.json"))
        MacroEnergy.copy_case(
            source_case,
            output_case;
            overwrite=true,
            preserve_tdr_output_features=true,
        )
        @test isfile(joinpath(output_case, "TDR", "output_features", "output_features.csv.gz"))
        @test isfile(joinpath(output_case, "TDR", "output_features", "output_metadata.json"))

        system_features = joinpath(output_case, "TDR", "systems", "system_2", "output_features")
        mkpath(system_features)
        touch(joinpath(system_features, "output_features.csv.gz"))
        touch(joinpath(system_features, "output_metadata.json"))
        MacroEnergy.copy_case(
            source_case,
            output_case;
            overwrite=true,
            preserve_tdr_output_features=true,
        )
        @test isfile(joinpath(output_case, "TDR", "systems", "system_2", "output_features", "output_features.csv.gz"))
        @test isfile(joinpath(output_case, "TDR", "systems", "system_2", "output_features", "output_metadata.json"))
    end

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

    tdr_defaults = MacroEnergy.default_tdr_settings()
    @test Set(keys(tdr_defaults)) == Set([
        "timesteps_per_representative_period",
        "representative_periods",
        "method",
        "scaling",
        "features",
        "exclude",
        "extreme_periods",
        "output_based_features",
    ])
    @test MacroEnergy.tdr_method_setting_names("kmeans") == Set(("restarts", "verbose"))
    @test_throws ArgumentError MacroEnergy.tdr_merge_settings(
        Dict("unexpected" => true),
        MacroEnergy.default_tdr_settings(),
        "settings",
    )
    @test Set(keys(MacroEnergy.TDR_OUTPUT_PROVIDERS)) == Set(("flow", "storage_level"))
    @test MacroEnergy.tdr_output_provider("flow") === MacroEnergy.tdr_flow_provider
    @test MacroEnergy.tdr_subperiod_run_kwargs(NamedTuple()).lazy_load
    @test !MacroEnergy.tdr_subperiod_run_kwargs((lazy_load=false,)).lazy_load

    @testset "per-System TDR settings" begin
        mktempdir() do temporary_root
            settings_path = joinpath(temporary_root, "time_domain_reduction.json")
            base_settings = Dict(
                "timesteps_per_representative_period" => 24,
                "representative_periods" => 2,
                "method" => Dict("name" => "kmeans"),
                "scaling" => "standardize",
            )
            MacroEnergy.write_json(settings_path, base_settings)
            scalar_settings = MacroEnergy.load_tdr_settings_by_system(settings_path, 2)
            @test length(scalar_settings) == 2
            @test scalar_settings[1] !== scalar_settings[2]
            @test all(settings -> settings.representative_periods == 2, scalar_settings)

            MacroEnergy.write_json(settings_path, merge(base_settings, Dict(
                "representative_periods" => [2, 3],
            )))
            count_settings = MacroEnergy.load_tdr_settings_by_system(settings_path, 2)
            @test getfield.(count_settings, :representative_periods) == [2, 3]
            @test_throws ArgumentError MacroEnergy.load_tdr_settings_by_system(settings_path, 3)

            MacroEnergy.write_json(settings_path, Dict("systems" => [
                base_settings,
                Dict(
                    "timesteps_per_representative_period" => 12,
                    "representative_periods" => 4,
                    "method" => Dict("name" => "kmedoids"),
                    "scaling" => "normalize",
                ),
            ]))
            system_settings = MacroEnergy.load_tdr_settings_by_system(settings_path, 2)
            @test system_settings[1].method_settings isa MacroEnergy.TDRKMeansSettings
            @test system_settings[2].method_settings isa MacroEnergy.TDRKMedoidsSettings
            @test system_settings[2].timesteps_per_representative_period == 12
            @test_throws ArgumentError MacroEnergy.load_tdr_settings_by_system(settings_path, 3)

            MacroEnergy.write_json(settings_path, merge(base_settings, Dict(
                "systems" => [base_settings, base_settings],
            )))
            @test_throws ArgumentError MacroEnergy.load_tdr_settings_by_system(settings_path, 2)
        end
    end

    kmedoids_settings = MacroEnergy.load_tdr_method_settings(Dict(
        "name" => "kmedoids",
        "settings" => Dict("restarts" => 2, "verbose" => true),
    ))
    @test kmedoids_settings isa MacroEnergy.TDRKMedoidsSettings
    @test kmedoids_settings.restarts == 2
    @test kmedoids_settings.verbose

    autoencoder_settings = MacroEnergy.load_tdr_method_settings(Dict(
        "name" => "autoencoder_simultaneous",
        "settings" => Dict("epochs" => 1, "latent_dim" => 2, "lambda" => 0.25),
    ))
    @test autoencoder_settings isa MacroEnergy.TDRAutoencoderSimultaneousSettings
    @test autoencoder_settings.epochs == 1
    @test autoencoder_settings.latent_dim == 2
    @test autoencoder_settings.lambda == 0.25
    @test_throws ArgumentError MacroEnergy.TDRKMeansSettings(restarts=-1)
    @test_throws ArgumentError MacroEnergy.TDRAutoencoderSequentialSettings(epochs=0)
    @test_throws ArgumentError MacroEnergy.TDRAutoencoderSimultaneousSettings(lambda=-0.1)
    @test_throws ArgumentError MacroEnergy.TDRSubperiodRunSettings(workers=2)
    @test_throws ArgumentError MacroEnergy.TDROutputFeatureSpec(provider="")
    @test_throws ArgumentError MacroEnergy.load_tdr_method_settings(Dict(
        "name" => "kmeans",
        "settings" => Dict("unexpected" => true),
    ))

    output_feature_settings = MacroEnergy.load_tdr_output_features(Dict(
        "weight" => 0.75,
        "save_features" => true,
        "reuse_saved_features" => false,
        "features" => [
            Dict("provider" => "flow", "weight" => 1.0),
            Dict("provider" => "flow", "commodity" => "Electricity", "asset" => "VRE", "weight" => 3.0),
        ],
    ))
    selected_output_feature = MacroEnergy.tdr_selected_output_feature(
        output_feature_settings.features,
        "flow",
    )
    @test selected_output_feature.user_weight == 3.0
    @test selected_output_feature.asset == "VRE"
    @test output_feature_settings.save_features
    @test !output_feature_settings.reuse_saved_features
    @test output_feature_settings.subperiod_runs == MacroEnergy.TDRSubperiodRunSettings()
    @test_throws ArgumentError MacroEnergy.load_tdr_output_features(Dict(
        "weight" => 0.75,
        "features" => [Dict("provider" => "flow")],
        "unexpected" => true,
    ))
    mktempdir() do temporary_root
        @test !MacroEnergy.tdr_saved_output_features_exist(temporary_root)
        mkpath(joinpath(temporary_root, "TDR", "output_features"))
        touch(MacroEnergy.tdr_output_features_path(temporary_root))
        @test !MacroEnergy.tdr_saved_output_features_exist(temporary_root)
        touch(MacroEnergy.tdr_output_metadata_path(temporary_root))
        @test MacroEnergy.tdr_saved_output_features_exist(temporary_root)
    end
    subperiod_run_settings = MacroEnergy.load_tdr_subperiod_run_settings(Dict(
        "distributed" => true,
        "workers" => 2,
        "include_policy_constraints" => false,
        "save_subperiod_inputs" => true,
        "save_subperiod_results" => true,
    ))
    @test subperiod_run_settings.workers == 2
    @test !subperiod_run_settings.include_policy_constraints
    @test_throws ArgumentError MacroEnergy.load_tdr_subperiod_run_settings(Dict(
        "distributed" => false, "workers" => 2,
    ))

    demand_reference = (
        json_file="system/nodes.json",
        input_path=Any[],
        feature_id="demand",
        field="demand",
        asset=nothing,
        commodity="Electricity",
        user_weight=1.0,
        include_in_clustering=true,
    )
    demand_source = MacroEnergy.TimeSeriesSource(
        "inline:demand",
        nothing,
        nothing,
        "system/nodes.json",
        Any[],
        [1.0, 1.0, 5.0, 5.0, 2.0, 2.0],
        1,
        NamedTuple[demand_reference],
        1,
        1.0,
        1.0,
        true,
    )
    extreme_specification = MacroEnergy.tdr_extreme_period_spec(Dict(
        "feature" => Dict("id" => "demand", "field" => "demand", "commodity" => "Electricity"),
        "aggregation" => "integral",
        "select" => "max",
    ))
    extreme_sources = MacroEnergy.tdr_extreme_period_sources(
        [demand_source],
        extreme_specification,
        PREPARE_CASE_TEST_INPUTS,
    )
    @test MacroEnergy.tdr_extreme_period(extreme_sources, extreme_specification, 2) == 2
    peak_specification = MacroEnergy.tdr_extreme_period_spec(Dict(
        "feature" => Dict("field" => "demand"),
        "aggregation" => "peak",
        "select" => "max",
    ))
    @test peak_specification.aggregation == :peak
    @test_throws ArgumentError MacroEnergy.tdr_extreme_period_spec(Dict(
        "feature" => Dict("field" => "demand"),
        "aggregation" => "absolute",
        "select" => "max",
    ))

    extreme_settings = MacroEnergy.load_time_domain_reduction_settings(
        joinpath(PREPARE_CASE_TEST_INPUTS, "settings", "time_domain_reduction.json"),
    )
    @test length(extreme_settings.extreme_periods) == 1
    @test only(extreme_settings.extreme_periods).feature.commodity == "Electricity"

    full_year_values, trailing_hours = MacroEnergy.tdr_time_series_values(
        collect(1.0:8760.0),
        "test full-year series",
        8736,
        8760,
    )
    @test length(full_year_values) == 8736
    @test full_year_values[end] == 8736.0
    @test trailing_hours == 24

    forced_cluster_settings = MacroEnergy.TDRSettings(
        timesteps_per_representative_period=2,
        representative_periods=2,
        method_settings=MacroEnergy.TDRKMeansSettings(restarts=1),
        scaling=:standardize,
        all_features=MacroEnergy.TDRFeatureSpec[],
        features=MacroEnergy.TDRFeatureSpec[],
        excluded_features=MacroEnergy.TDRFeatureSpec[],
        extreme_periods=MacroEnergy.TDRExtremePeriodSpec[],
    )
    cluster_representatives, cluster_period_map = MacroEnergy.tdr_cluster(
        [demand_source],
        6,
        forced_cluster_settings;
        extreme_periods=[2],
    )
    @test 2 in cluster_representatives
    @test cluster_period_map[2] == findfirst(==(2), cluster_representatives)

    output_source = deepcopy(demand_source)
    output_source.key = "output:flow:vre"
    output_source.user_weight = 3.0
    output_source.weight = 3.0
    MacroEnergy.tdr_set_clustering_weights!([demand_source], [output_source], 0.75)
    @test demand_source.weight == 0.25
    @test output_source.weight == 0.75

    for method_name in ("autoencoder_sequential", "autoencoder_simultaneous")
        method_data = Dict{String,Any}(
            "restarts" => 1,
            "epochs" => 1,
            "patience" => 1,
            "warmup" => 0,
            "n_filters" => 1,
            "latent_dim" => 1,
        )
        method_name == "autoencoder_simultaneous" && (method_data["lambda"] = 0.1)
        method_settings = MacroEnergy.load_tdr_method_settings(Dict(
            "name" => method_name,
            "settings" => method_data,
        ))
        autoencoder_cluster_settings = MacroEnergy.TDRSettings(
            timesteps_per_representative_period=2,
            representative_periods=2,
            method_settings=method_settings,
            scaling=:standardize,
            all_features=MacroEnergy.TDRFeatureSpec[],
            features=MacroEnergy.TDRFeatureSpec[],
            excluded_features=MacroEnergy.TDRFeatureSpec[],
            extreme_periods=MacroEnergy.TDRExtremePeriodSpec[],
        )
        representatives, period_map = MacroEnergy.tdr_cluster(
            [demand_source],
            6,
            autoencoder_cluster_settings,
        )
        @test length(representatives) == 2
        @test length(period_map) == 3
    end

    existing_period_map = DataFrame(
        Period_Index=collect(1:60),
        Rep_Period=repeat([101, 102, 103, 104]; inner=15),
        Rep_Period_Index=repeat(collect(1:4); inner=15),
    )
    composed_period_map = MacroEnergy.tdr_compose_period_map(
        existing_period_map,
        [2, 4],
        [1, 1, 2, 2],
    )
    @test composed_period_map.Period_Index == collect(1:60)
    @test composed_period_map.Rep_Period == vcat(fill(102, 30), fill(104, 30))
    @test composed_period_map.Rep_Period_Index == vcat(fill(1, 30), fill(2, 30))

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
        all_sources, _, _, _, _, _ = MacroEnergy.tdr_sources(source_case, settings)
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
        excluded_sources, _, _, _, _, _ = MacroEnergy.tdr_sources(source_case, excluded_settings)
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
                    "include_policy_constraints" => false,
                    "save_subperiod_inputs" => true,
                    "save_subperiod_results" => true,
                ),
            ),
        ))
        output_settings = MacroEnergy.load_time_domain_reduction_settings(output_settings_path)
        subperiod_case = joinpath(temporary_root, "subperiod_case")
        MacroEnergy.tdr_materialize_subperiod_case!(source_case, subperiod_case, 2, output_settings)
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
        @test isfile(joinpath(output_case, "time_domain_reduction_provenance.json"))
        @test isfile(joinpath(output_case, "preprocess_log.json"))
        @test_throws ArgumentError preprocess_inputs(source_case, output_case; tdr_settings_path=settings_path)

        reduced_time_data = JSON3.read(read(joinpath(output_case, "system", "time_data.json"), String))
        @test reduced_time_data[:NumberOfSubperiods] == 3
        @test reduced_time_data[:TotalHoursModeled] == full_length
        reduced_map = CSV.read(joinpath(output_case, "system", "period_map.csv"), DataFrame)
        @test nrow(reduced_map) == full_length ÷ PREPARE_CASE_PERIOD_LENGTH
        @test length(unique(reduced_map.Rep_Period_Index)) == 3
        @test nrow(CSV.read(joinpath(output_case, "system", "demand.csv"), DataFrame)) == 3 * PREPARE_CASE_PERIOD_LENGTH
        provenance = JSON3.read(read(joinpath(output_case, "time_domain_reduction_provenance.json"), String))
        @test length(provenance[:forced_extreme_periods]) == 1
        @test only(provenance[:forced_extreme_periods]) in provenance[:representative_periods]
        preprocess_log = JSON3.read(read(joinpath(output_case, "preprocess_log.json"), String))
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
        case, solution = run_case(output_case; log_to_console=false, log_to_file=false)
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
            @test MacroEnergy.tdr_prepare_system_inputs!(source_case) == 2
            prepared_system_data = MacroEnergy.read_json(joinpath(source_case, "system_data.json"))
            @test startswith(prepared_system_data["case"][1]["time_data"]["path"], "system/system_1/")
            @test prepared_system_data["case"][2]["assets"]["path"] == "assets/system_2"
            subperiod_case = joinpath(temporary_root, "system_2_period_1")
            MacroEnergy.tdr_materialize_subperiod_case!(
                source_case,
                subperiod_case,
                1,
                output_settings;
                system_index=2,
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
                joinpath(source_case, "TDR", "systems", "system_2", "subperiod_solves", "period_0001")
        end
    end
end
