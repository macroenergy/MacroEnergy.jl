module TestTDRSystemScopes

using Test, CSV, DataFrames
import MacroEnergy as ME

function configuration(; representatives=1, output_features=false)
    data = Dict{String,Any}(
        "timesteps_per_representative_period" => 2, "representative_periods" => representatives,
        "method" => Dict("name" => "kmeans", "settings" => Dict("restarts" => 1)),
        "scaling" => "standardize", "exclude" => [Dict("commodity" => "Hydrogen")],
    )
    if output_features
        data["output_based_features"] = Dict("weight" => 0.5, "features" => [Dict("provider" => "flow")])
    end
    return data
end

function fixture(root, form)
    mkpath(root)
    count = form == :multi ? 2 : 1
    CSV.write(joinpath(root, "hydrogen.csv"), DataFrame(
        one=collect(11.:16.), two=collect(21.:26.), unused=zeros(6)))
    ME.write_json(joinpath(root, "time.json"), Dict(
        "HoursPerTimeStep" => Dict("Electricity" => 1, "Hydrogen" => 1),
        "HoursPerSubperiod" => Dict("Electricity" => 2, "Hydrogen" => 2),
        "NumberOfSubperiods" => 3, "TotalHoursModeled" => 6))
    systems = map(1:count) do index
        nodes = Any[Dict("type" => "Electricity", "instance_data" => [
            Dict("id" => "independent", "demand" => collect(21.:26.) .+ 100index)])]
        if form == :multi
            path = "external_$index.json"
            ME.write_json(joinpath(root, path), Dict("nodes" => [Dict(
                "type" => "Electricity", "instance_data" => [
                    Dict("id" => "external", "demand" => collect(31.:36.) .+ 100index)])]))
            push!(nodes, Dict("path" => path))
        end
        Dict("commodities" => ["Electricity", "Hydrogen"],
            "time_data" => Dict("path" => "time.json"),
            "settings" => Dict("WriteSubcommodities" => false), "assets" => Any[], "nodes" => nodes,
            "locations" => [Dict("id" => "SE", "commodities" => Dict(
                "Electricity" => Dict("demand" => [1.,2.,9.,10.,20.,21.] .+ 100index,
                    "price" => collect(41.:46.) .+ 100index, "max_nsd" => [0.]),
                "Hydrogen" => Dict("demand" => Dict("timeseries" => Dict(
                    "path" => "hydrogen.csv", "header" => index == 1 ? "one" : "two"))),
            ))])
    end
    document = form == :bare ? only(systems) : Dict(
        "case" => systems, "settings" => Dict("PeriodLengths" => ones(Int, count)),
        "metadata" => Dict("demand" => fill(999., 6)))
    ME.write_json(joinpath(root, "system_data.json"), document)
    return systems
end

function loaded_system(root, data)
    system = ME.empty_system(root)
    ME.generate_system!(system, copy(data))
    return system
end

function check_profiles(system, index, rows; external=false)
    node = ME.find_node(system, :SE, ME.Electricity)
    @test node.demand == ([1.,2.,9.,10.,20.,21.] .+ 100index)[rows]
    @test node.price == (collect(41.:46.) .+ 100index)[rows]
    @test node.max_nsd == [0.]
    @test length(node.timedata.time_interval) == length(rows)
    @test ME.find_node(system, :SE, ME.Hydrogen).demand == (collect(1.:6.) .+ 10index)[rows]
    @test ME.find_node(system, :independent).demand == (collect(21.:26.) .+ 100index)[rows]
    if external
        @test ME.find_node(system, :external).demand == (collect(31.:36.) .+ 100index)[rows]
    end
end

@testset "Canonical TDR System scopes" begin
    for form in (:bare, :wrapped, :multi)
        @testset "$form inline discovery, reduction and isolated periods" begin
            mktempdir() do temporary
                source = joinpath(temporary, "source")
                original_systems = fixture(source, form)
                original_files = Dict(joinpath(source, file) => read(joinpath(source, file)) for file in readdir(source))
                output_settings = ME.load_tdr_settings_data(configuration(; output_features=true))
                prepared = ME.tdr_prepare_inputs(source, [deepcopy(output_settings) for _ in original_systems])
                root_path = joinpath(source, "system_data.json")
                for (index, inputs) in enumerate(prepared.systems)
                    prefix = form == :bare ? Any[] : Any["case", index]
                    @test inputs.system_scope.file == root_path
                    @test inputs.system_scope.path == prefix
                    @test inputs.input_data[root_path] === inputs.system
                    @test length(inputs.sources) == (form == :multi ? 5 : 4)
                    demand = only(filter(series -> series.inline_file == root_path &&
                        "locations" in series.inline_path && last(series.inline_path) == "demand", inputs.sources))
                    @test demand.values == [1.,2.,9.,10.,20.,21.] .+ 100index
                    @test demand.inline_path == [prefix; Any["locations", 1, "commodities", "Electricity", "demand"]]
                    @test !only(filter(series -> !isnothing(series.csv_path), inputs.sources)).include_in_clustering
                    for series in inputs.sources, reference in series.references
                        reference.json_file == root_path || continue
                        @test reference.input_path[1:length(prefix)] == prefix
                    end

                    isolated = joinpath(temporary, "isolated_$index")
                    relocated = ME.tdr_relocate_inputs(inputs, isolated; system_path=Any[])
                    @test isempty(relocated.system_scope.path)
                    @test relocated.system === relocated.input_data[joinpath(isolated, "system_data.json")]
                    for series in relocated.sources, reference in series.references
                        reference.json_file == relocated.system_scope.file || continue
                        @test first(reference.input_path) in ("locations", "nodes")
                    end
                    ME.tdr_materialize_subperiod_case!(ME.tdr_prepare_subperiod_inputs(inputs), isolated, 2, output_settings)
                    data = ME.read_json(joinpath(isolated, "system_data.json"))
                    @test !haskey(data, :case)
                    check_profiles(loaded_system(isolated, data), index, [3,4]; external=form == :multi)
                    @test inputs.system_scope.path == prefix
                end

                config_path = joinpath(temporary, "tdr.json")
                ME.write_json(config_path, configuration(; representatives=form == :multi ? [1,2] : 1))
                reduced = joinpath(temporary, "reduced")
                ME.preprocess_inputs(source, reduced; tdr_settings_path=config_path)
                generated = ME.read_json(joinpath(reduced, "system_data.json"))
                @test haskey(generated, :case) == (form != :bare)
                if form != :bare
                    @test generated[:metadata][:demand] == fill(999., 6)
                end
                systems = form == :bare ? [generated] : generated[:case]
                log = ME.read_json(joinpath(reduced, "preprocessing_logs", "preprocess_log.json"))[:time_domain_reduction]
                for (index, system_data) in enumerate(systems)
                    time = ME.read_json(joinpath(reduced, system_data[:time_data][:path]))
                    map = CSV.read(joinpath(reduced, time[:SubPeriodMap][:path]), DataFrame)
                    count = form == :multi ? index : 1
                    representatives = [first(map.Rep_Period[map.Rep_Period_Index .== slot]) for slot in 1:count]
                    rows = vcat([(period-1)*2 .+ (1:2) for period in representatives]...)
                    check_profiles(loaded_system(reduced, system_data), index, rows; external=form == :multi)
                    record = form == :multi ? log[:systems][Symbol("system_$index")] : log
                    inline = filter(series -> series[:source][:type] == "inline_json" &&
                        series[:source][:path] == "system_data.json", record[:discovered_time_series][:sources])
                    @test length(inline) == 3
                    prefix = form == :bare ? String[] : ["case", string(index)]
                    @test all(series -> series[:source][:input_path][1:length(prefix)] == prefix, inline)
                end
                @test all(read(path) == contents for (path, contents) in original_files)
            end
        end
    end

    @testset "Systems with different horizons stay isolated" begin
        mktempdir() do source
            systems = map(enumerate((4, 6))) do (index, hours)
                path = "time_$index.json"
                ME.write_json(joinpath(source, path), Dict("HoursPerTimeStep" => Dict("Electricity" => 1),
                    "HoursPerSubperiod" => Dict("Electricity" => 2), "NumberOfSubperiods" => hours ÷ 2,
                    "TotalHoursModeled" => hours))
                Dict("time_data" => Dict("path" => path), "locations" => [Dict("id" => "SE",
                    "commodities" => Dict("Electricity" => Dict("demand" => collect(1.:hours) .+ 100index)))])
            end
            ME.write_json(joinpath(source, "system_data.json"), Dict("case" => systems))
            settings = ME.load_tdr_settings_data(configuration())
            prepared = ME.tdr_prepare_inputs(source, [settings, settings])
            for (index, hours) in enumerate((4,6))
                series = only(prepared.systems[index].sources)
                @test series.values == collect(1.:hours) .+ 100index
                @test series.occurrences == 1
                @test series.inline_path[1:2] == Any["case", index]
            end
        end
    end

    @testset "A path from another System cannot be rebased" begin
        first_scope = ME.TDRInputScope("system_data.json", Any["case", 1])
        second_scope = ME.TDRInputScope("system_data.json", Any["case", 2])
        @test_throws r"outside its System scope" ME.tdr_rebase_input_path(Any["case", 2, "demand"], first_scope, second_scope)
    end
end

end # module
