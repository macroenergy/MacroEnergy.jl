using CSV, DataFrames, MacroEnergy, Test

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
