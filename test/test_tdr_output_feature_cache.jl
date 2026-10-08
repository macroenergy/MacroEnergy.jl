using CSV, DataFrames, MacroEnergy, Test

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

@testset "single-System cached output-feature provenance" begin
    mktempdir() do root
        source = joinpath(root, "source")
        output = joinpath(root, "output")
        mkpath(source)
        MacroEnergy.write_json(joinpath(source, "system_data.json"), Dict(
            "time_data" => Dict("path" => "time_data.json"),
            "nodes" => Dict("path" => "nodes.json")))
        MacroEnergy.write_json(joinpath(source, "time_data.json"), Dict(
            "HoursPerTimeStep" => Dict("Electricity" => 1),
            "HoursPerSubperiod" => Dict("Electricity" => 2),
            "NumberOfSubperiods" => 2, "TotalHoursModeled" => 4))
        MacroEnergy.write_json(joinpath(source, "nodes.json"), Dict(
            "demand" => Dict("timeseries" => Dict("path" => "demand.csv", "header" => "demand"))))
        CSV.write(joinpath(source, "demand.csv"), DataFrame(demand=[1, 1, 9, 9]))
        run_settings = Dict(
            "distributed" => true, "workers" => 2, "exclude_policy_constraints" => true,
            "save_subperiod_inputs" => true, "save_subperiod_results" => true)
        settings_path = joinpath(root, "tdr.json")
        MacroEnergy.write_json(settings_path, Dict(
            "timesteps_per_representative_period" => 2, "representative_periods" => 1,
            "method" => Dict("name" => "kmeans"), "scaling" => "standardize",
            "output_based_features" => Dict("weight" => 0.5,
                "save_features" => true, "reuse_saved_features" => true,
                "subperiod_runs" => run_settings, "features" => [Dict("provider" => "flow")])))
        settings = MacroEnergy.load_time_domain_reduction_settings(settings_path)
        feature = only(settings.output_features.features)
        results = [(period=period, outputs=Dict("output:flow:test" => [(feature, values)]))
            for (period, values) in enumerate(([2.0, 2.0], [8.0, 8.0]))]
        sources = MacroEnergy.tdr_output_sources_from_results(results, [1, 2], settings)
        # Seed the source cache so preprocessing can reuse it in a new destination,
        # then complete both provenance and log writing without a solve.
        MacroEnergy.tdr_write_output_features!(source, sources, settings, 4)
        @test preprocess_inputs(source, output; tdr_settings_path=settings_path, overwrite=true) === nothing
        provenance = MacroEnergy.mutable_json_data(MacroEnergy.read_json(
            joinpath(output, "time_domain_reduction_provenance.json")))
        @test provenance["settings"]["output_based_features"]["subperiod_runs"] == run_settings
        @test only(provenance["subperiod_solves"])["reused_saved_features"]
        @test isfile(joinpath(output, "preprocess_log.json"))
        @test nrow(CSV.read(joinpath(output, "demand.csv"), DataFrame)) == 2
        @test nrow(CSV.read(joinpath(source, "demand.csv"), DataFrame)) == 4
    end
end

@testset "output-feature cache fingerprints" begin
    mktempdir() do root
        source = joinpath(root, "source")
        mkpath(joinpath(source, "settings"))
        mkpath(joinpath(source, "user_additions"))
        MacroEnergy.write_json(joinpath(source, "time_data.json"), Dict(
            "HoursPerTimeStep" => Dict("Electricity" => 1),
            "HoursPerSubperiod" => Dict("Electricity" => 2),
            "NumberOfSubperiods" => 2, "TotalHoursModeled" => 4))
        CSV.write(joinpath(source, "demand.csv"), DataFrame(demand=[1, 1, 9, 9]))
        systems = [Dict("time_data" => Dict("path" => "time_data.json"),
            "nodes" => Dict("path" => "nodes_$index.json")) for index in 1:2]
        for index in 1:2
            MacroEnergy.write_json(joinpath(source, "nodes_$index.json"), Dict(
                "demand" => Dict("timeseries" => Dict("path" => "demand.csv", "header" => "demand"))))
        end
        MacroEnergy.write_json(joinpath(source, "system_data.json"), Dict(
            "case" => systems, "settings" => Dict("path" => "settings/case_settings.json")))
        MacroEnergy.write_json(joinpath(source, "settings", "case_settings.json"), Dict("PeriodLengths" => [1, 1]))
        write(joinpath(source, "user_additions", "custom.jl"), "# user code\n")
        config = Dict(
            "timesteps_per_representative_period" => 2, "representative_periods" => 1,
            "method" => Dict("name" => "kmeans"), "scaling" => "standardize",
            "output_based_features" => Dict("weight" => 0.5,
                "save_features" => true, "reuse_saved_features" => true,
                "features" => [Dict("provider" => "flow", "weight" => 2.0)]))
        settings_path = joinpath(root, "tdr.json")
        function parse_config(data)
            MacroEnergy.write_json(settings_path, data)
            return MacroEnergy.load_time_domain_reduction_settings(settings_path)
        end
        settings = parse_config(config)
        fingerprint(index=1; directory=source, kwargs...) = MacroEnergy.tdr_output_cache_fingerprint(
            directory, settings, 4; system_index=index, kwargs...)
        baseline = fingerprint()
        baseline_two = fingerprint(2)
        @test baseline isa MacroEnergy.TDROutputCacheFingerprint
        @test baseline.inputs isa MacroEnergy.TDROutputCacheInputs
        @test eltype(baseline.inputs.files) == MacroEnergy.TDROutputCacheFile
        @test eltype(baseline.inputs.feature_selection) == MacroEnergy.TDROutputCacheFeatureSelection
        # The typed payload and its serialized form describe the same exclusions.
        legacy_inputs = Dict(
            "cache_version" => MacroEnergy.TDR_OUTPUT_CACHE_VERSION, "system_index" => 1,
            "system" => baseline.inputs.system, "case" => baseline.inputs.case,
            "files" => [Dict("path" => file.path, "sha256" => file.sha256)
                for file in baseline.inputs.files],
            "full_length" => 4, "timesteps_per_representative_period" => 2,
            "exclude_policy_constraints" => String[],
            "feature_selection" => [Dict("id" => nothing, "provider" => "flow",
                "asset" => nothing, "commodity" => nothing)],
        )
        legacy_fingerprint = Dict("sha256" => bytes2hex(MacroEnergy.SHA.sha256(
            MacroEnergy.tdr_cache_json(legacy_inputs))), "inputs" => legacy_inputs)
        @test baseline.sha256 == legacy_fingerprint["sha256"]
        @test MacroEnergy.tdr_cache_data(baseline) == legacy_fingerprint
        function exclusion_fingerprint(exclusion)
            changed = deepcopy(config)
            changed["output_based_features"]["subperiod_runs"] = Dict("exclude_policy_constraints" => exclusion)
            return MacroEnergy.tdr_output_cache_fingerprint(source, parse_config(changed), 4; system_index=1)
        end
        @test exclusion_fingerprint(String[]).sha256 == baseline.sha256
        selected = exclusion_fingerprint(["CO2CapConstraint", "AggregatedDemandConstraint"])
        @test selected.sha256 == exclusion_fingerprint(["AggregatedDemandConstraint", "CO2CapConstraint", "CO2CapConstraint"]).sha256
        @test selected.sha256 != baseline.sha256
        @test selected.sha256 != exclusion_fingerprint(["CO2CapConstraint"]).sha256
        @test exclusion_fingerprint(true).sha256 == exclusion_fingerprint(sort!(collect(MacroEnergy.tdr_policy_constraint_names()))).sha256
        hashes = Dict{String,String}()
        @test fingerprint(; file_hashes=hashes).sha256 == baseline.sha256
        first_count = length(hashes)
        @test fingerprint(2; file_hashes=hashes).sha256 == baseline_two.sha256
        @test length(hashes) == first_count + 1 # Only nodes_2.json is additional.

        moved = joinpath(root, "moved")
        cp(source, moved)
        @test fingerprint(; directory=moved).sha256 == baseline.sha256
        mkpath(joinpath(source, "TDR", "subperiod_solves"))
        write(joinpath(source, "TDR", "subperiod_solves", "unused.jl"), "# retained artifact\n")
        @test fingerprint().sha256 == baseline.sha256
        @test MacroEnergy.tdr_cache_json(Dict("a" => 1, "b" => 2)) ==
            MacroEnergy.tdr_cache_json(Dict("b" => 2, "a" => 1))

        feature = only(settings.output_features.features)
        results = [(period=period, outputs=Dict("output:flow:test" => [(feature, values)]))
            for (period, values) in enumerate(([2.0, 2.0], [8.0, 8.0]))]
        sources = MacroEnergy.tdr_output_sources_from_results(results, [1, 2], settings)
        solver = MacroEnergy.tdr_output_solver_provenance((optimizer=:original,
            optimizer_attributes=("tolerance" => 0.01,)))
        MacroEnergy.tdr_write_output_features!(source, sources, settings, 4;
            system_index=1, solver_provenance=solver)
        saved = MacroEnergy.mutable_json_data(MacroEnergy.read_json(
            MacroEnergy.tdr_output_metadata_path(source; system_index=1)))
        @test saved["fingerprint"] == legacy_fingerprint
        reused = MacroEnergy.tdr_output_sources(source, [settings, settings],
            MacroEnergy.tdr_prepare_inputs(source, [settings, settings]).systems[1:1];
            run_case_kwargs=(optimizer=:different, optimizer_attributes=("tolerance" => 0.1,)))
        @test only(reused[1][2])["reused_saved_features"]
        @test only(reused[1][2])["solver_provenance"] == solver

        reweighted_config = deepcopy(config)
        reweighted_config["representative_periods"] = 2
        reweighted_config["scaling"] = "normalize"
        reweighted_config["output_based_features"]["weight"] = 0.7
        reweighted_config["output_based_features"]["features"][1]["weight"] = 5.0
        reweighted_config["output_based_features"]["subperiod_runs"] = Dict(
            "distributed" => true, "workers" => 2, "save_subperiod_inputs" => true)
        reweighted = parse_config(reweighted_config)
        @test MacroEnergy.tdr_output_cache_fingerprint(source, reweighted, 4; system_index=1).sha256 == baseline.sha256
        loaded = only(MacroEnergy.tdr_load_output_features(source, reweighted, 4; system_index=1))
        @test loaded.values == only(sources).values
        @test loaded.user_weight == 5.0
        @test loaded.weight == 5.0
        @test only(loaded.references).user_weight == 5.0

        for change in (:policy, :period, :selection)
            changed = deepcopy(config)
            if change == :policy
                changed["output_based_features"]["subperiod_runs"] = Dict("exclude_policy_constraints" => true)
            elseif change == :period
                changed["timesteps_per_representative_period"] = 4
            else
                changed["output_based_features"]["features"][1]["provider"] = "storage_level"
            end
            @test_throws MacroEnergy.TDROutputCacheMismatch MacroEnergy.tdr_load_output_features(
                source, parse_config(changed), 4; system_index=1)
        end
        @test_throws MacroEnergy.TDROutputCacheMismatch MacroEnergy.tdr_load_output_features(
            source, settings, 8; system_index=1)

        # A change belonging exclusively to another System leaves this cache reusable.
        nodes_two = joinpath(source, "nodes_2.json")
        original = read(nodes_two, String)
        write(nodes_two, original * "\n")
        @test fingerprint().sha256 == baseline.sha256
        @test fingerprint(2).sha256 != baseline_two.sha256
        write(nodes_two, original)
        for path in (joinpath(source, "demand.csv"),
            joinpath(source, "settings", "case_settings.json"),
            joinpath(source, "user_additions", "custom.jl"))
            original = read(path, String)
            write(path, original * "\n")
            @test fingerprint().sha256 != baseline.sha256
            @test_throws MacroEnergy.TDROutputCacheMismatch MacroEnergy.tdr_load_output_features(
                source, settings, 4; system_index=1)
            write(path, original)
        end

        metadata_path = MacroEnergy.tdr_output_metadata_path(source; system_index=1)
        metadata = MacroEnergy.mutable_json_data(MacroEnergy.read_json(metadata_path))
        metadata["cache_version"] = 0 # A version incompatible with the current cache schema.
        MacroEnergy.write_json(metadata_path, metadata)
        @test_throws MacroEnergy.TDROutputCacheMismatch MacroEnergy.tdr_load_output_features(
            source, settings, 4; system_index=1)
        delete!(metadata, "cache_version")
        MacroEnergy.write_json(metadata_path, metadata)
        @test_throws MacroEnergy.TDROutputCacheMismatch MacroEnergy.tdr_load_output_features(
            source, settings, 4; system_index=1)
    end
end

@testset "subperiod inputs preserve Case settings" begin
    for representation in (:bare_file, :bare_defaults, :case_file, :case_inline, :case_defaults, :multi)
        @testset "$representation" begin
            mktempdir() do root
                source = joinpath(root, "source")
                destination = joinpath(root, "subperiod")
                mkpath(source)
                system = Dict("time_data" => Dict("path" => "time_data.json"),
                    "nodes" => Dict("path" => "nodes.json"))
                MacroEnergy.write_json(joinpath(source, "time_data.json"), Dict(
                    "HoursPerTimeStep" => Dict("Electricity" => 1),
                    "HoursPerSubperiod" => Dict("Electricity" => 2),
                    "NumberOfSubperiods" => 2, "TotalHoursModeled" => 4))
                MacroEnergy.write_json(joinpath(source, "nodes.json"), Dict(
                    "demand" => Dict("timeseries" => Dict("path" => "demand.csv", "header" => "demand"))))
                CSV.write(joinpath(source, "demand.csv"), DataFrame(demand=[1, 2, 3, 4]))
                custom_settings = Dict("PeriodLengths" => representation == :multi ? [5, 7] : [5],
                    "DiscountRate" => 0.08, "StartYear" => 2030,
                    "ParameterScaling" => true, "SolutionAlgorithm" => "Monolithic",
                    "ExpansionHorizon" => "Myopic")
                defaults = representation in (:bare_defaults, :case_defaults)
                case_root = representation in (:bare_file, :bare_defaults) ? system :
                    Dict{String,Any}("case" => representation == :multi ? [system, deepcopy(system)] : [system])
                if representation == :case_inline
                    case_root["settings"] = custom_settings
                elseif !defaults
                    relative_path = representation == :bare_file ? joinpath("settings", "case_settings.json") :
                        joinpath("custom", "case.json")
                    mkpath(dirname(joinpath(source, relative_path)))
                    MacroEnergy.write_json(joinpath(source, relative_path), custom_settings)
                    if representation != :bare_file
                        case_root["settings"] = Dict("path" => MacroEnergy.tdr_normalize_path(relative_path))
                        # Explicit Cases must not accidentally pick this conventional file.
                        mkpath(joinpath(source, "settings"))
                        MacroEnergy.write_json(joinpath(source, "settings", "case_settings.json"),
                            Dict("PeriodLengths" => [99], "DiscountRate" => 0.99))
                    end
                end
                MacroEnergy.write_json(joinpath(source, "system_data.json"), case_root)
                original_source = read(joinpath(source, "system_data.json"), String)
                settings = MacroEnergy.load_tdr_settings_data(Dict(
                    "timesteps_per_representative_period" => 2, "representative_periods" => 1,
                    "method" => Dict("name" => "kmeans"), "scaling" => "standardize",
                    "output_based_features" => Dict("weight" => 0.5, "features" => [Dict("provider" => "flow")],
                        "subperiod_runs" => Dict("exclude_policy_constraints" => false))))
                index = representation == :multi ? 2 : nothing
                prepared = MacroEnergy.tdr_prepare_inputs(source,
                    fill(settings, representation == :multi ? 2 : 1))
                subperiod_inputs = MacroEnergy.tdr_prepare_subperiod_inputs(prepared.systems[something(index, 1)])
                MacroEnergy.tdr_materialize_subperiod_case!(subperiod_inputs, destination, 2, settings)
                # Follow the standalone-System loader's actual settings discovery/configuration.
                discovered = MacroEnergy.single_system_case_settings(joinpath(destination, "system_data.json"))
                configured = MacroEnergy.configure_case(discovered, destination)
                @test configured[:PeriodLengths] == (defaults ? [1] : representation == :multi ? [7] : [5])
                @test configured[:DiscountRate] == (defaults ? 0.0 : 0.08)
                @test configured[:ParameterScaling] == !defaults
                @test configured[:ExpansionHorizon] isa MacroEnergy.PerfectForesight
                @test CSV.read(joinpath(destination, "demand.csv"), DataFrame).demand == [3, 4]
                @test !haskey(MacroEnergy.read_json(joinpath(destination, "system_data.json")), "case")
                @test read(joinpath(source, "system_data.json"), String) == original_source
            end
        end
    end
end
