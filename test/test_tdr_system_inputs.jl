using CSV, DataFrames, MacroEnergy, Test

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

        manifest = Set(keys(MacroEnergy.tdr_case_input_manifest(case_root)))
        json_files = Set(path for path in manifest if MacroEnergy.isjson(path))
        @test json_files == Set(abspath.([
            joinpath(case_root, "system_data.json"),
            joinpath(case_root, "inputs", "time_data.json"),
            joinpath(case_root, "assets", "asset.json"),
            joinpath(case_root, "inputs", "nested.json"),
        ]))

        @test joinpath(case_root, "data", "availability.csv") in manifest
        @test joinpath(case_root, "notes.md") in manifest
        @test all(ispath, manifest)
    end
end

@testset "per-System TDR input manifests" begin
    mktempdir() do root
        source = joinpath(root, "source")
        output = joinpath(root, "output")
        mkpath.(joinpath.(source, ("data", joinpath("custom", "one"),
            joinpath("custom", "two"), joinpath("custom", "one", "unused"), "settings")))
        time_data = Dict(
            "HoursPerTimeStep" => Dict("Electricity" => 1),
            "HoursPerSubperiod" => Dict("Electricity" => 2),
            "NumberOfSubperiods" => 2, "TotalHoursModeled" => 4,
        )
        MacroEnergy.write_json(joinpath(source, "time_data.json"), time_data)
        CSV.write(joinpath(source, "data", "demand.csv"), DataFrame(Time_Index=1:4, demand=[1, 1, 9, 9]))
        MacroEnergy.write_json(joinpath(source, "shared.json"), Dict(
            "demand" => Dict("timeseries" => Dict(
                "path" => "data/demand.csv", "header" => "demand")),
            "availability" => [0.1, 0.1, 0.9, 0.9],
        ))
        for name in ("one", "two")
            MacroEnergy.write_json(joinpath(source, "custom", name, "asset.json"), Dict(
                "input" => Dict("path" => "shared.json")))
        end
        # A directory reference loads immediate files, not an unrelated subdirectory.
        MacroEnergy.write_json(joinpath(source, "custom", "one", "unused", "other.json"), Dict())
        MacroEnergy.write_json(joinpath(source, "settings", "case_settings.json"), Dict("PeriodLengths" => [1, 1]))
        systems = [Dict(
            "time_data" => Dict("path" => "time_data.json"),
            "assets" => Dict("path" => "custom/$name"),
        ) for name in ("one", "two")]
        MacroEnergy.write_json(joinpath(source, "system_data.json"), Dict(
            "case" => systems, "settings" => Dict("path" => "settings/case_settings.json")))
        manifest = Set(relpath(path, source) for path in keys(MacroEnergy.tdr_system_input_manifest(source, systems[1])))
        @test manifest == Set(("time_data.json", joinpath("custom", "one"),
            joinpath("custom", "one", "asset.json"), "shared.json", joinpath("data", "demand.csv")))

        settings_path = joinpath(root, "tdr.json")
        MacroEnergy.write_json(settings_path, Dict(
            "timesteps_per_representative_period" => 2,
            "representative_periods" => [1, 2],
            "method" => Dict("name" => "kmeans"), "scaling" => "standardize",
        ))
        @test preprocess_inputs(source, output; tdr_settings_path=settings_path) === nothing
        generated = MacroEnergy.read_json(joinpath(output, "system_data.json"))
        @test generated["settings"]["path"] == "settings/case_settings.json"
        @test isfile(joinpath(output, "settings", "case_settings.json"))
        for (index, name) in enumerate(("one", "two"))
            private = joinpath(output, "inputs", "system_$index")
            @test generated["case"][index]["assets"]["path"] == "inputs/system_$index/custom/$name"
            @test generated["case"][index]["time_data"]["path"] == "inputs/system_$index/time_data.json"
            @test isfile(joinpath(private, "custom", name, "asset.json"))
            @test !isdir(joinpath(private, "custom", index == 1 ? "two" : "one"))
            @test !isdir(joinpath(private, "custom", name, "unused"))
            asset = MacroEnergy.read_json(joinpath(private, "custom", name, "asset.json"))
            @test asset["input"]["path"] == "inputs/system_$index/shared.json"
            shared = MacroEnergy.read_json(joinpath(private, "shared.json"))
            @test shared["demand"]["timeseries"]["path"] == "inputs/system_$index/data/demand.csv"
            @test length(shared["availability"]) == 2 * index
            @test nrow(CSV.read(joinpath(private, "data", "demand.csv"), DataFrame)) == 2 * index
        end
        @test nrow(CSV.read(joinpath(source, "data", "demand.csv"), DataFrame)) == 4
        @test MacroEnergy.read_json(joinpath(source, "shared.json"))["availability"] == [0.1, 0.1, 0.9, 0.9]
        @test !isfile(joinpath(output, "data", "demand.csv"))
        # Preparation can be repeated without nesting inputs/system_N again.
        prepared = MacroEnergy.tdr_prepare_inputs(output,
            MacroEnergy.load_tdr_settings_by_system(settings_path, 2))
        @test length(MacroEnergy.tdr_prepare_system_inputs!(output, prepared).systems) == 2
        @test MacroEnergy.read_json(joinpath(output, "system_data.json")) == generated
        @test !isdir(joinpath(output, "inputs", "system_1", "inputs"))
    end

    @testset "distinct groups of identical reduced CSVs" begin
        mktempdir() do root
            mkpath(joinpath(root, "data"))
            CSV.write(joinpath(root, "data", "demand.csv"), DataFrame(demand=[1, 1, 9, 9]))
            MacroEnergy.write_json(joinpath(root, "time_data.json"), Dict(
                "HoursPerTimeStep" => Dict("Electricity" => 1),
                "HoursPerSubperiod" => Dict("Electricity" => 2),
                "NumberOfSubperiods" => 2, "TotalHoursModeled" => 4,
            ))
            MacroEnergy.write_json(joinpath(root, "nodes.json"), Dict(
                "demand" => Dict("timeseries" => Dict("path" => "data/demand.csv", "header" => "demand"))))
            system = Dict("time_data" => Dict("path" => "time_data.json"),
                "nodes" => Dict("path" => "nodes.json"))
            MacroEnergy.write_json(joinpath(root, "system_data.json"), Dict("case" => [deepcopy(system) for _ in 1:4]))
            settings_path = joinpath(root, "tdr.json")
            MacroEnergy.write_json(settings_path, Dict(
                "timesteps_per_representative_period" => 2, "representative_periods" => [1, 1, 2, 2],
                "method" => Dict("name" => "kmeans"), "scaling" => "standardize"))
            time_domain_reduction(root, settings_path)
            systems = MacroEnergy.read_json(joinpath(root, "system_data.json"))["case"]
            nodes = [MacroEnergy.read_json(joinpath(root, String(system["nodes"]["path"]))) for system in systems]
            paths = [String(node["demand"]["timeseries"]["path"]) for node in nodes]
            @test paths[1] == paths[2]
            @test paths[3] == paths[4]
            @test paths[1] != paths[3]
            @test nrow(CSV.read(joinpath(root, paths[1]), DataFrame)) == 2
            @test CSV.read(joinpath(root, paths[3]), DataFrame).demand == [1, 1, 9, 9]
            @test all(isfile(joinpath(root, String(system["time_data"]["path"]))) for system in systems)
        end
    end
end

@testset "directly referenced JSON consolidation" begin
    mktempdir() do root
        mkpath(joinpath(root, "assets"))
        MacroEnergy.write_json(joinpath(root, "time.json"), Dict(
            "HoursPerTimeStep" => Dict("Electricity" => 1),
            "HoursPerSubperiod" => Dict("Electricity" => 2),
            "NumberOfSubperiods" => 2, "TotalHoursModeled" => 4))
        MacroEnergy.write_json(joinpath(root, "static.json"), Dict("commodities" => ["Electricity"]))
        MacroEnergy.write_json(joinpath(root, "parent.json"), Dict("child" => Dict("path" => "static.json")))
        MacroEnergy.write_json(joinpath(root, "assets", "asset.json"), Dict("value" => 1))
        MacroEnergy.write_json(joinpath(root, "variable.json"), Dict("availability" => [1, 1, 2, 2]))
        system = Dict("time_data" => Dict("path" => "time.json"),
            "commodities" => Dict("path" => "static.json"),
            "settings" => Dict("path" => "parent.json"),
            "nodes" => Dict("path" => "variable.json"),
            "assets" => Dict("path" => "assets"),
            "direct_asset" => Dict("path" => "assets/asset.json"))
        MacroEnergy.write_json(joinpath(root, "system_data.json"), Dict("case" => [deepcopy(system), deepcopy(system)]))
        settings = joinpath(root, "tdr.json")
        MacroEnergy.write_json(settings, Dict("timesteps_per_representative_period" => 2,
            "representative_periods" => [1, 2], "method" => Dict("name" => "kmeans"),
            "scaling" => "standardize"))
        time_domain_reduction(root, settings)
        systems = MacroEnergy.read_json(joinpath(root, "system_data.json"))["case"]
        path(index, key) = String(systems[index][key]["path"])
        @test path(1, "commodities") == path(2, "commodities") == "static.json"
        @test path(1, "settings") == path(2, "settings") == "parent.json"
        parent = MacroEnergy.read_json(joinpath(root, path(1, "settings")))
        @test parent["child"]["path"] == path(1, "commodities")
        @test path(1, "nodes") != path(2, "nodes")
        @test path(1, "time_data") != path(2, "time_data")
        @test path(1, "direct_asset") != path(2, "direct_asset")
        for index in 1:2
            @test isfile(joinpath(root, path(index, "assets"), "asset.json"))
            @test isfile(joinpath(root, path(index, "direct_asset")))
            @test !isfile(joinpath(root, "inputs", "system_$index", "static.json"))
            @test !isfile(joinpath(root, "inputs", "system_$index", "parent.json"))
            @test isfile(joinpath(root, path(index, "nodes")))
        end
        @test MacroEnergy.read_json(joinpath(root, "static.json"))["commodities"] == ["Electricity"]
        # A subsequent preprocessing pass can discover the consolidated tree.
        prepared = MacroEnergy.tdr_prepare_inputs(root,
            MacroEnergy.load_tdr_settings_by_system(settings, 2))
        @test length(prepared.systems) == 2
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
