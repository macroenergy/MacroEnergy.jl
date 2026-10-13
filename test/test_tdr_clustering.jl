using DataFrames, MacroEnergy, Test

@testset "TDR clustering and extreme-period selection" begin
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
        joinpath(@__DIR__, "test_inputs"),
    )
    @test MacroEnergy.tdr_extreme_period_selection(extreme_sources, extreme_specification, 2).period == 2
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
        joinpath(joinpath(@__DIR__, "test_inputs"), "settings", "time_domain_reduction.json"),
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

    existing_period_map = DataFrame(
        Period_Index=collect(1:60),
        Rep_Period=repeat([1, 16, 31, 46]; inner=15),
        Rep_Period_Index=repeat(collect(1:4); inner=15),
    )
    existing_candidates = MacroEnergy.TDRCandidatePeriods(1, 1,
        Int.(existing_period_map.Rep_Period_Index), [period:period for period in 1:4],
        Int.(existing_period_map.Rep_Period_Index), fill(15, 4), [1, 16, 31, 46], 0)
    composed_period_map = MacroEnergy.tdr_compose_period_map(
        existing_candidates,
        [2, 4],
        [1, 1, 2, 2],
    )
    @test composed_period_map.Period_Index == collect(1:60)
    @test composed_period_map.Rep_Period == vcat(fill(16, 30), fill(46, 30))
    @test composed_period_map.Rep_Period_Index == vcat(fill(1, 30), fill(2, 30))
end

@testset "TDR autoencoder clustering" begin
    for method in ("autoencoder_sequential", "autoencoder_simultaneous")
        method_settings = Dict{String,Any}("kernel_size" => 1, "stride" => 1,
            "epochs" => 1, "min_err_diff" => 0.0, "patience" => 1,
            "warmup" => 0, "n_filters" => 2, "latent_dim" => 2)
        method == "autoencoder_simultaneous" && (method_settings["lambda"] = 0.1)
        settings = MacroEnergy.load_tdr_settings_data(Dict(
            "timesteps_per_representative_period" => 2, "representative_periods" => 2,
            "method" => Dict("name" => method, "settings" => method_settings), "scaling" => "standardize"))
        profiles = MacroEnergy.TimeSeriesSource("demand", nothing, nothing, nothing, Any[],
            [0., 0, 2, 2, 10, 10], 1, NamedTuple[], 1, 1.0, 1.0, true)
        for weights in (nothing, [3, 1, 1])
            @testset "$method, candidate weights: $weights" begin
                clustering_kwargs = isnothing(weights) ? NamedTuple() : (; candidate_weights=weights)
                representatives, assignments = MacroEnergy.tdr_cluster([profiles], 6, settings; clustering_kwargs...)
                @test length(representatives) == 2
                @test allunique(representatives)
                @test length(assignments) == 3
                @test Set(assignments) == Set((1, 2))
            end
        end
    end
end
