using CSV, DataFrames, MacroEnergy, Test

@testset "TDR inline recognition independent of clustering" begin
    mktempdir() do root
        source = joinpath(root, "source")
        mkpath(source)
        MacroEnergy.write_json(joinpath(source, "system_data.json"), Dict(
            "time_data" => Dict("path" => "time.json"), "nodes" => Dict("path" => "profiles.json")))
        MacroEnergy.write_json(joinpath(source, "time.json"), Dict(
            "HoursPerTimeStep" => Dict("Electricity" => 1),
            "HoursPerSubperiod" => Dict("Electricity" => 4),
            "NumberOfSubperiods" => 2, "TotalHoursModeled" => 10))
        data = Dict(
            "demand" => collect(1:8), "price" => collect(11:20),
            "availability" => collect(21:28), "min_storage_level" => collect(31:38),
            "max_storage_level" => collect(41:48),
            "balance_data" => Dict("conversion" => collect(51:58)),
            "constant" => [7], "scalar" => 8, "short" => [2, 3],
            "labels" => fill("label", 8), "nested" => [Dict("coefficient" => collect(61:68))])
        path = joinpath(source, "profiles.json")
        MacroEnergy.write_json(path, data)
        original = read(path)
        config = Dict("timesteps_per_representative_period" => 2, "representative_periods" => 1,
            "scaling" => "standardize", "method" => Dict("name" => "kmeans"),
            "exclude" => [Dict("field" => "availability"), Dict("field" => "min_storage_level")])
        settings = MacroEnergy.load_tdr_settings_data(config)
        prepared = MacroEnergy.tdr_prepare_inputs(source, [settings])
        sources = only(prepared.systems).sources
        by_field = Dict(only(series.references).field => series for series in sources)
        @test Set(keys(by_field)) == Set(("demand", "price", "availability", "min_storage_level",
            "max_storage_level", "conversion", "coefficient"))
        @test only(filter(series -> series.include_in_clustering, sources)) === by_field["demand"]
        @test by_field["price"].values == collect(11:18)
        @test only(prepared.systems).trailing_hours == 2
        @test only(by_field["price"].references).clustering_exclusion_reason == "no_matching_feature"
        for field in ("availability", "min_storage_level")
            @test only(by_field[field].references).clustering_exclusion_reason == "explicitly_excluded"
        end
        @test isnothing(only(by_field["demand"].references).clustering_exclusion_reason)
        @test length(settings.excluded_features) == 2
        entry = MacroEnergy.TDRLogEntry(by_field["price"], source)
        @test entry.source isa MacroEnergy.TDRLogLocation
        @test entry.references isa Vector{MacroEnergy.TDRLogReference}
        @test entry.fields == ["price"]
        @test entry.reduced && !entry.include_in_clustering
        @test only(entry.references).clustering_exclusion_reason == "no_matching_feature"
        @test MacroEnergy.tdr_log_data(entry) == MacroEnergy.tdr_source_log_data(by_field["price"], source)
        defaults = MacroEnergy.TDRLogEntry(source=MacroEnergy.TDRLogLocation(type="output_feature"))
        @test defaults.occurrences == 0 && defaults.user_weight == 1.0 && defaults.weight == 0.0
        @test !defaults.reduced && !defaults.include_in_clustering && isempty(defaults.references)
        @test MacroEnergy.tdr_log_data(defaults)["source"] == Dict("type" => "output_feature")
        push!(defaults.fields, "test")
        @test isempty(MacroEnergy.TDRLogEntry(source=defaults.source).fields)

        settings_path = joinpath(root, "settings.json")
        MacroEnergy.write_json(settings_path, config)
        output = joinpath(root, "reduced")
        preprocess_inputs(source, output; tdr_settings_path=settings_path)
        reduced = MacroEnergy.mutable_json_data(MacroEnergy.read_json(joinpath(output, "profiles.json")))
        representative = Int(only(CSV.read(joinpath(output, "period_map.csv"), DataFrame).Rep_Period[1:1]))
        rows = (representative - 1) * 2 .+ (1:2)
        for field in ("demand", "price", "availability", "min_storage_level", "max_storage_level")
            @test reduced[field] == data[field][rows]
        end
        @test reduced["balance_data"]["conversion"] == data["balance_data"]["conversion"][rows]
        @test reduced["nested"][1]["coefficient"] == data["nested"][1]["coefficient"][rows]
        for field in ("constant", "scalar", "short", "labels")
            @test reduced[field] == data[field]
        end
        @test read(path) == original
        log = MacroEnergy.read_json(joinpath(output, "preprocess_log.json"))["time_domain_reduction"]
        logged = Dict(only(series["fields"]) => series for series in log["discovered_time_series"]["sources"])
        @test length(logged) == length(sources)
        @test all(series["reduced"] for series in values(logged))
        @test logged["demand"]["include_in_clustering"]
        @test !logged["price"]["include_in_clustering"]
        @test only(logged["price"]["references"])["path"] == "profiles.json"
        @test only(logged["price"]["references"])["input_path"] == ["price"]
        @test only(logged["price"]["references"])["clustering_exclusion_reason"] == "no_matching_feature"
        @test only(logged["availability"]["references"])["clustering_exclusion_reason"] == "explicitly_excluded"
        @test only(log["clustering_features"]["sources"])["fields"] == ["demand"]
        @test only(MacroEnergy.tdr_source_log_data(by_field["demand"], source;
            include_in_clustering=false)["references"])["clustering_exclusion_reason"] == "zero_clustering_weight"

        output_config = deepcopy(config)
        output_config["output_based_features"] = Dict("weight" => 0.5, "features" => [Dict("provider" => "flow")])
        output_settings = MacroEnergy.load_tdr_settings_data(output_config)
        inputs = only(MacroEnergy.tdr_prepare_inputs(source, [output_settings]).systems)
        subperiod = joinpath(root, "subperiod")
        MacroEnergy.tdr_materialize_subperiod_case!(MacroEnergy.tdr_prepare_subperiod_inputs(inputs), subperiod, 2, output_settings)
        sliced = MacroEnergy.mutable_json_data(MacroEnergy.read_json(joinpath(subperiod, "profiles.json")))
        for field in ("demand", "price", "availability", "min_storage_level", "max_storage_level")
            @test sliced[field] == data[field][3:4]
        end
        @test sliced["balance_data"]["conversion"] == data["balance_data"]["conversion"][3:4]
        @test sliced["nested"][1]["coefficient"] == data["nested"][1]["coefficient"][3:4]
        @test sliced["constant"] == [7]
    end
end
