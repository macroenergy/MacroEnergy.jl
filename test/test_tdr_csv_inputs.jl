using CSV, DataFrames, MacroEnergy, Test

@testset "TDR model CSV references" begin
    mktempdir() do root
        source = joinpath(root, "source")
        mkpath(joinpath(source, "data"))
        MacroEnergy.write_json(joinpath(source, "time.json"), Dict(
            "HoursPerTimeStep" => Dict("Electricity" => 1),
            "HoursPerSubperiod" => Dict("Electricity" => 2),
            "NumberOfSubperiods" => 2, "TotalHoursModeled" => 4))
        CSV.write(joinpath(source, "data", "profiles.csv"), DataFrame(
            Time_Index=1:4, solar=[1, 1, 9, 9], hydro=[2, 2, 8, 8], unused=11:14))
        CSV.write(joinpath(source, "ordinary.csv"), DataFrame(label=["one", "two"], value=[7, 8]))
        MacroEnergy.write_json(joinpath(source, "metadata.json"), Dict("value" => "shared"))
        # Keep a deliberately different column order from the parser's Type/id order.
        original = DataFrame(
            "note" => ["quoted, text", "second row"],
            "availability--timeseries--header" => ["solar", "hydro"],
            "id" => ["asset_b", "asset_a"],
            "Type" => ["VRE", "Hydro"],
            "availability--timeseries--path" => fill("data/profiles.csv", 2),
            "metadata--path" => fill("metadata.json", 2),
            "ordinary--path" => fill("ordinary.csv", 2),
            "optional" => [missing, 4.5])
        asset_path = joinpath(source, "assets.csv")
        CSV.write(asset_path, original)
        original_bytes = read(asset_path)
        node_table = DataFrame("Type" => ["CO2"], "id" => ["co2_node"],
            "time_interval" => ["CO2"],
            "constraints--CO2CapConstraint" => [true],
            "constraints--BalanceConstraint" => [false],
            "rhs_policy--CO2CapConstraint" => [100])
        CSV.write(joinpath(source, "nodes.csv"), node_table)
        system = Dict("time_data" => Dict("path" => "time.json"),
            "nodes" => Dict("path" => "nodes.csv"),
            "assets" => Dict("path" => "assets.csv"))
        MacroEnergy.write_json(joinpath(source, "system_data.json"), Dict("case" => [deepcopy(system), deepcopy(system)],
            "settings" => Dict("PeriodLengths" => [1, 1], "SolutionAlgorithm" => "Monolithic")))
        settings_path = joinpath(root, "tdr.json")
        MacroEnergy.write_json(settings_path, Dict("timesteps_per_representative_period" => 2,
            "representative_periods" => [1, 2], "scaling" => "standardize",
            "method" => Dict("name" => "kmeans")))
        settings = MacroEnergy.load_tdr_settings_by_system(settings_path, 2)
        prepared = MacroEnergy.tdr_prepare_inputs(source, settings)
        inputs = prepared.systems[1]
        @test haskey(inputs.input_data, asset_path)
        @test haskey(inputs.csv_tables, asset_path)
        @test inputs.manifest[joinpath(source, "data", "profiles.csv")].columns == Set((:solar, :hydro))
        @test haskey(inputs.manifest, joinpath(source, "ordinary.csv"))
        @test isnothing(inputs.manifest[joinpath(source, "ordinary.csv")].columns)
        @test length(inputs.sources) == 2
        @test Set(ref.asset for series in inputs.sources for ref in series.references) == Set(("VRE", "Hydro"))

        # The shared dictionary workflow rewrites every supported path and the
        # format adapter reparses to precisely that adjusted representation.
        destination = joinpath(root, "isolated")
        relocated = MacroEnergy.tdr_relocate_inputs(inputs, destination; private_index=1)
        copied_asset = joinpath(destination, "inputs", "system_1", "assets.csv")
        mkpath(dirname(copied_asset))
        MacroEnergy.tdr_write_input_data(copied_asset, relocated.input_data[copied_asset], relocated.csv_tables)
        @test isequal(MacroEnergy.tdr_read_input_data(copied_asset), relocated.input_data[copied_asset])
        frame = CSV.read(copied_asset, DataFrame)
        @test names(frame) == names(original)
        @test frame.id == original.id
        @test frame.note == original.note
        @test isequal(frame.optional, original.optional)
        @test frame[!, "ordinary--path"] == fill("inputs/system_1/ordinary.csv", 2)
        @test frame[!, "metadata--path"] == fill("inputs/system_1/metadata.json", 2)

        # Isolated candidate inputs use the same snapshots/format adapter.
        output_settings = MacroEnergy.load_tdr_settings_data(Dict(
            "timesteps_per_representative_period" => 2, "representative_periods" => 1,
            "scaling" => "standardize", "method" => Dict("name" => "kmeans"),
            "output_based_features" => Dict("weight" => 0.5, "save_features" => true,
                "features" => [Dict("provider" => "flow")],
                "subperiod_runs" => Dict("include_policy_constraints" => false))))
        output_inputs = MacroEnergy.tdr_prepare_inputs(source, [output_settings, deepcopy(output_settings)])
        fingerprint = output_inputs.systems[1].cache_fingerprint
        @test "data/profiles.csv" in [file.path for file in fingerprint.inputs.files]
        @test "ordinary.csv" in [file.path for file in fingerprint.inputs.files]
        template = MacroEnergy.tdr_prepare_subperiod_inputs(output_inputs.systems[1])
        subperiod = joinpath(root, "subperiod")
        MacroEnergy.tdr_materialize_subperiod_case!(template, subperiod, 2, output_settings)
        subperiod_frame = CSV.read(joinpath(subperiod, "assets.csv"), DataFrame)
        @test names(subperiod_frame) == names(original)
        @test subperiod_frame.id == original.id
        @test subperiod_frame[!, "metadata--path"] == fill("metadata.json", 2)
        @test CSV.read(joinpath(subperiod, "data", "profiles.csv"), DataFrame).solar == [9, 9]
        subperiod_nodes = CSV.read(joinpath(subperiod, "nodes.csv"), DataFrame)
        @test names(subperiod_nodes) == filter(header -> !endswith(header, "--CO2CapConstraint"), names(node_table))
        subperiod_data = MacroEnergy.tdr_read_input_data(joinpath(subperiod, "nodes.csv"))
        node = only(only(values(subperiod_data)))["instance_data"]
        @test !haskey(node["constraints"], "CO2CapConstraint")
        @test node["constraints"]["BalanceConstraint"] == false
        CSV.write(joinpath(source, "data", "profiles.csv"), DataFrame(
            Time_Index=1:4, solar=[1, 1, 10, 10], hydro=[2, 2, 8, 8], unused=11:14))
        changed = MacroEnergy.tdr_prepare_inputs(source, [output_settings, deepcopy(output_settings)])
        @test changed.systems[1].cache_fingerprint.sha256 != fingerprint.sha256
        CSV.write(joinpath(source, "data", "profiles.csv"), DataFrame(
            Time_Index=1:4, solar=[1, 1, 9, 9], hydro=[2, 2, 8, 8], unused=11:14))

        output = joinpath(root, "output")
        preprocess_inputs(source, output; tdr_settings_path=settings_path)
        generated = MacroEnergy.read_json(joinpath(output, "system_data.json"))["case"]
        for index in 1:2
            path = joinpath(output, String(generated[index]["assets"]["path"]))
            @test endswith(path, ".csv")
            frame = CSV.read(path, DataFrame)
            @test names(frame) == names(original)
            @test frame.id == original.id
            @test frame[!, "availability--timeseries--header"] == ["solar", "hydro"]
            for reference in frame[!, "availability--timeseries--path"]
                series = CSV.read(joinpath(output, reference), DataFrame)
                @test nrow(series) == 2 * index
                @test names(series) == ["Time_Index", "solar", "hydro"]
            end
            @test frame[!, "metadata--path"] == fill("metadata.json", 2)
            @test isfile(joinpath(output, frame[1, "metadata--path"]))
            @test CSV.read(joinpath(output, frame[1, "ordinary--path"]), DataFrame).value == [7, 8]
            @test !isfile(joinpath(dirname(path), "assets.json"))
        end
        @test read(asset_path) == original_bytes
        @test CSV.read(joinpath(source, "data", "profiles.csv"), DataFrame).unused == collect(11:14)

        # Identical reductions consolidate the series, and CSV consumers must
        # be rewritten to the consolidated path as well.
        common = joinpath(root, "common")
        common_settings = joinpath(root, "common_settings.json")
        MacroEnergy.write_json(common_settings, Dict("timesteps_per_representative_period" => 2,
            "representative_periods" => 2, "scaling" => "standardize",
            "method" => Dict("name" => "kmeans")))
        preprocess_inputs(source, common; tdr_settings_path=common_settings)
        systems = MacroEnergy.read_json(joinpath(common, "system_data.json"))["case"]
        for system in systems
            frame = CSV.read(joinpath(common, String(system["assets"]["path"])), DataFrame)
            @test frame[!, "availability--timeseries--path"] == fill("data/profiles.csv", 2)
            @test isfile(joinpath(common, frame[1, "availability--timeseries--path"]))
        end

        # Single-System copies must relocate absolute references too, rather
        # than continuing to read unreduced series from the source Case.
        single_source = joinpath(root, "single_source")
        cp(source, single_source)
        single_table = copy(original)
        for header in ("availability--timeseries--path", "metadata--path", "ordinary--path")
            single_table[!, header] = [joinpath(single_source, value) for value in single_table[!, header]]
        end
        CSV.write(joinpath(single_source, "assets.csv"), single_table)
        MacroEnergy.write_json(joinpath(single_source, "system_data.json"), system)
        single_output = joinpath(root, "single_output")
        preprocess_inputs(single_source, single_output; tdr_settings_path=common_settings)
        single_frame = CSV.read(joinpath(single_output, "assets.csv"), DataFrame)
        @test single_frame[!, "availability--timeseries--path"] == fill("data/profiles.csv", 2)
        @test single_frame[!, "ordinary--path"] == fill("ordinary.csv", 2)
        @test single_frame[!, "metadata--path"] == fill("metadata.json", 2)
    end
end

@testset "CSV model inputs in directories load after TDR" begin
    mktempdir() do root
        source = joinpath(root, "source")
        cp(joinpath(@__DIR__, "test_inputs"), source)
        vre_path = joinpath(source, "assets", "vre.json")
        data = MacroEnergy.mutable_json_data(MacroEnergy.read_json(vre_path))
        definition = only(data["solar_pv"])
        function flatten!(row, data, prefix="")
            for (key, value) in data
                address = isempty(prefix) ? key : prefix * "--" * key
                if value isa AbstractDict
                    flatten!(row, value, address)
                else
                    row[Symbol(address)] = value
                end
            end
            return row
        end
        rows = [flatten!(Dict{Symbol,Any}(:Type => "VRE"),
            MacroEnergy.recursive_merge(definition["global_data"], instance))
            for instance in definition["instance_data"]]
        table = DataFrame(rows)
        select!(table, [:Type, :id, sort!(setdiff(propertynames(table), [:Type, :id]))...])
        csv_path = joinpath(source, "assets", "vre.csv")
        CSV.write(csv_path, table)
        rm(vre_path)
        source_bytes = read(csv_path)
        original = MacroEnergy.load_system(source)
        original_vre = filter(asset -> asset isa MacroEnergy.VRE, original.assets)
        @test length(original_vre) == nrow(table)
        settings_path = joinpath(root, "tdr.json")
        MacroEnergy.write_json(settings_path, Dict("timesteps_per_representative_period" => 168,
            "representative_periods" => 2, "scaling" => "standardize",
            "method" => Dict("name" => "kmeans")))
        output = joinpath(root, "output")
        preprocess_inputs(source, output; tdr_settings_path=settings_path)
        reduced = MacroEnergy.load_system(output)
        reduced_vre = filter(asset -> asset isa MacroEnergy.VRE, reduced.assets)
        @test [asset.id for asset in reduced_vre] == [asset.id for asset in original_vre]
        @test all(length(asset.edge.availability) == 336 for asset in reduced_vre)
        @test names(CSV.read(joinpath(output, "assets", "vre.csv"), DataFrame)) == names(table)
        @test !isfile(joinpath(output, "assets", "vre.json"))
        @test read(csv_path) == source_bytes
    end
end

@testset "model CSV ordinary references recurse and terminate cycles" begin
    mktempdir() do root
        CSV.write(joinpath(root, "assets.csv"), DataFrame(
            "Type" => ["VRE"], "id" => ["a"], "input--path" => ["nested.json"]))
        MacroEnergy.write_json(joinpath(root, "nested.json"), Dict("next" => Dict("path" => "other.csv")))
        CSV.write(joinpath(root, "other.csv"), DataFrame(
            "Type" => ["VRE"], "id" => ["b"], "input--path" => ["assets.csv"]))
        manifest = MacroEnergy.tdr_system_input_manifest(root, Dict("assets" => Dict("path" => "assets.csv")))
        @test Set(basename.(keys(manifest))) == Set(("assets.csv", "nested.json", "other.csv"))
        @test all(isnothing(input.columns) for input in values(manifest))
    end
end
