using MacroEnergy, Test

@testset "TDR settings and output providers" begin
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
    subperiod_run_settings = MacroEnergy.load_tdr_subperiod_run_settings(Dict(
        "distributed" => true,
        "workers" => 2,
        "exclude_policy_constraints" => true,
        "save_subperiod_inputs" => true,
        "save_subperiod_results" => true,
    ))
    @test subperiod_run_settings.workers == 2
    @test subperiod_run_settings.exclude_policy_constraints
    @test_throws ArgumentError MacroEnergy.load_tdr_subperiod_run_settings(Dict(
        "distributed" => false, "workers" => 2,
    ))
end

@testset "selective TDR policy exclusion settings" begin
    parse(exclude) = MacroEnergy.load_tdr_subperiod_run_settings(Dict("exclude_policy_constraints" => exclude))
    @test MacroEnergy.TDRSubperiodRunSettings().exclude_policy_constraints === false
    @test isempty(MacroEnergy.tdr_policy_constraint_names(parse(false).exclude_policy_constraints))
    @test MacroEnergy.tdr_policy_constraint_names(parse(true).exclude_policy_constraints) == MacroEnergy.tdr_policy_constraint_names()
    @test isempty(MacroEnergy.tdr_policy_constraint_names(parse(String[]).exclude_policy_constraints))
    named = parse(["CO2CapConstraint", "AggregatedDemandConstraint", "CO2CapConstraint"])
    @test named.exclude_policy_constraints == ["AggregatedDemandConstraint", "CO2CapConstraint"]
    @test MacroEnergy.tdr_subperiod_run_settings_data(named)["exclude_policy_constraints"] == named.exclude_policy_constraints
    for invalid in ("CO2CapConstraint", 1, nothing, [true], ["AggregatedDemandConstrain"], ["BalanceConstraint"])
        @test_throws ArgumentError parse(invalid)
    end
    @test_throws ArgumentError MacroEnergy.load_tdr_subperiod_run_settings(Dict("include_policy_constraints" => true))
    @test_throws ArgumentError MacroEnergy.load_tdr_subperiod_run_settings(Dict(
        "include_policy_constraints" => true, "exclude_policy_constraints" => false))
    data = Dict("constraints" => Dict("CO2CapConstraint" => true, "AggregatedDemandConstraint" => true,
        "BalanceConstraint" => false), "rhs_policy" => Dict("CO2CapConstraint" => 100, "AggregatedDemandConstraint" => 200),
        "price_unmet_policy" => Dict("CO2CapConstraint" => 10, "AggregatedDemandConstraint" => 20))
    MacroEnergy.tdr_remove_policy_constraints!(data, MacroEnergy.tdr_policy_constraint_names(["CO2CapConstraint"]))
    @test data == Dict("constraints" => Dict("AggregatedDemandConstraint" => true, "BalanceConstraint" => false),
        "rhs_policy" => Dict("AggregatedDemandConstraint" => 200), "price_unmet_policy" => Dict("AggregatedDemandConstraint" => 20))
end

