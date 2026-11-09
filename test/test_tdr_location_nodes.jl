module TestTDRLocationNodes

using Test, CSV, DataFrames
import MacroEnergy as ME

function collect_sources(data, root, features; exclusions=ME.TDRFeatureSpec[],
    commodity_names=Set(["Electricity", "Hydrogen"]))
    sources = Dict{String,ME.TimeSeriesSource}()
    ME.tdr_collect_references!(sources, data, joinpath(root, "inputs.json"), root,
        4, 4, Ref(0), features, exclusions, commodity_names)
    return collect(values(sources))
end

function source_summary(sources)
    return Dict((only(source.references).commodity, only(source.references).field) =>
        (source.values, source.user_weight, source.include_in_clustering,
         only(source.references).clustering_exclusion_reason) for source in sources)
end

@testset "TDR location commodity context" begin
    generic = [ME.TDRFeatureSpec(field="demand"), ME.TDRFeatureSpec(field="supply.price")]
    features = [generic;
        ME.TDRFeatureSpec(field="demand", commodity="Electricity", user_weight=7.0);
        ME.TDRFeatureSpec(field="demand", commodity="Hydrogen", user_weight=3.0);
        ME.TDRFeatureSpec(field="supply.price", commodity="Electricity", user_weight=5.0)]
    exclusion = ME.TDRFeatureSpec(field="demand", commodity="Electricity")

    for storage in (:inline, :csv)
        @testset "$storage references reuse node traversal" begin
            mktempdir() do root
                CSV.write(joinpath(root, "profiles.csv"), DataFrame(
                    electricity=[1.,2.,3.,4.], hydrogen=[5.,6.,7.,8.], price=[2.,3.,5.,8.]))
                profile(header, values) = storage == :inline ? values :
                    Dict("timeseries"=>Dict("path"=>"profiles.csv", "header"=>header))
                node_data = Dict(
                    "Electricity"=>Dict("demand"=>profile("electricity", [1.,2.,3.,4.]),
                        "supply"=>Dict("grid"=>Dict("price"=>profile("price", [2.,3.,5.,8.])))),
                    "Hydrogen"=>Dict("demand"=>profile("hydrogen", [5.,6.,7.,8.])),
                )
                nested = Dict("locations"=>[Dict("id"=>"SE", "commodities"=>node_data)])
                independent = Dict("nodes"=>[Dict("type"=>name, "instance_data"=>deepcopy(details))
                    for (name, details) in node_data])
                original = deepcopy(nested)
                sources = collect_sources(nested, root, features)
                @test source_summary(sources) == source_summary(collect_sources(independent, root, features))
                @test length(sources) == 3
                by_key = Dict((only(source.references).commodity, only(source.references).field)=>source for source in sources)
                @test by_key[("Electricity", "demand")].user_weight == 7.0
                @test by_key[("Hydrogen", "demand")].user_weight == 3.0
                @test by_key[("Electricity", "supply.price")].user_weight == 5.0
                for source in sources
                    reference = only(source.references)
                    @test reference.asset === nothing
                    @test reference.input_path[1:4] == Any["locations", 1, "commodities", reference.commodity]
                    @test !("instance_data" in reference.input_path)
                    if storage == :inline
                        @test source.inline_path == reference.input_path
                    end
                end
                for selectors in (generic, features)
                    excluded = collect_sources(nested, root, selectors; exclusions=[exclusion])
                    @test source_summary(excluded) == source_summary(collect_sources(independent, root, selectors; exclusions=[exclusion]))
                    demand = only(filter(source -> only(source.references).commodity == "Electricity" &&
                        only(source.references).field == "demand", excluded))
                    @test !demand.include_in_clustering
                    @test only(demand.references).clustering_exclusion_reason == "explicitly_excluded"
                    @test only(filter(source -> only(source.references).commodity == "Hydrogen", excluded)).include_in_clustering
                end
                @test nested == original
                @test all(details -> !haskey(details, "type"), values(node_data))
            end
        end
    end

    @testset "Implicit subcommodity type and unrelated dictionaries" begin
        mktempdir() do root
            features = [ME.TDRFeatureSpec(field="demand"),
                ME.TDRFeatureSpec(field="demand", commodity="GreenHydrogen", user_weight=9.0)]
            for details in (Dict("demand"=>[1.,2.,3.,4.]),
                            Dict("type"=>"GreenHydrogen", "demand"=>[1.,2.,3.,4.]))
                raw = Dict("locations"=>[Dict("id"=>"SE", "commodities"=>Dict("GreenHydrogen"=>details))])
                source = only(collect_sources(raw, root, features))
                @test only(source.references).commodity == "GreenHydrogen"
                @test only(source.references).asset === nothing
                @test source.user_weight == 9.0
            end
            raw = Dict("id"=>"custom", "commodities"=>Dict("Electricity"=>Dict("demand"=>[1.,2.,3.,4.])))
            @test only(only(collect_sources(raw, root, features)).references).commodity === nothing
            raw = Dict("locations"=>[Dict("id"=>"SE", "metadata"=>Dict(
                "commodities"=>Dict("Electricity"=>Dict("demand"=>[1.,2.,3.,4.]))))])
            @test only(only(collect_sources(raw, root, features)).references).commodity === nothing
        end
    end

    @testset "End-to-end reduction preserves original node input paths" begin
        for inline_locations in (true, false)
            mktempdir() do root
                source_root = joinpath(root, "source")
                output_root = joinpath(root, "reduced")
                mkpath(source_root)
                CSV.write(joinpath(source_root, "hydrogen.csv"), DataFrame(hydrogen=[5.,6.,7.,8.]))
                locations = [Dict("id"=>"SE", "commodities"=>Dict(
                    "Electricity"=>Dict("demand"=>[1.,2.,9.,10.]),
                    "Hydrogen"=>Dict("demand"=>Dict("timeseries"=>Dict("path"=>"hydrogen.csv", "header"=>"hydrogen"))),
                ))]
                system = Dict("time_data"=>Dict("path"=>"time.json"),
                    "locations"=>inline_locations ? locations : Dict("path"=>"locations.json"))
                ME.write_json(joinpath(source_root, "system_data.json"), system)
                inline_locations || ME.write_json(joinpath(source_root, "locations.json"), Dict("locations"=>locations))
                ME.write_json(joinpath(source_root, "time.json"), Dict(
                    "HoursPerTimeStep"=>Dict("Electricity"=>1,"Hydrogen"=>1),
                    "HoursPerSubperiod"=>Dict("Electricity"=>2,"Hydrogen"=>2),
                    "NumberOfSubperiods"=>2, "TotalHoursModeled"=>4))
                config = Dict("timesteps_per_representative_period"=>2, "representative_periods"=>1, "scaling"=>"standardize",
                    "method"=>Dict("name"=>"kmeans"),
                    "features"=>[Dict("field"=>"demand","commodity"=>"Electricity","weight"=>7.0)],
                    "exclude"=>[Dict("field"=>"demand","commodity"=>"Hydrogen")])
                settings = ME.load_tdr_settings_data(config)
                prepared = ME.tdr_prepare_inputs(source_root, [settings])
                sources = only(prepared.systems).sources
                @test only(filter(series -> only(series.references).commodity == "Electricity", sources)).user_weight == 7.0
                @test !only(filter(series -> only(series.references).commodity == "Hydrogen", sources)).include_in_clustering
                json_path = joinpath(source_root, inline_locations ? "system_data.json" : "locations.json")
                original = read(json_path)
                settings_path = joinpath(root, "tdr.json")
                ME.write_json(settings_path, config)
                ME.preprocess_inputs(source_root, output_root; tdr_settings_path=settings_path)
                reduced = ME.mutable_json_data(ME.read_json(joinpath(output_root, basename(json_path))))
                node_data = only(reduced["locations"])["commodities"]
                representative = first(CSV.read(joinpath(output_root,"period_map.csv"), DataFrame).Rep_Period)
                rows = (representative-1)*2 .+ (1:2)
                @test node_data["Electricity"]["demand"] == [1.,2.,9.,10.][rows]
                @test !haskey(node_data["Electricity"], "type")
                @test !haskey(node_data["Electricity"], "instance_data")
                @test read(json_path) == original
                csv_path = joinpath(output_root, node_data["Hydrogen"]["demand"]["timeseries"]["path"])
                @test CSV.read(csv_path, DataFrame).hydrogen == [5.,6.,7.,8.][rows]
            end
        end
    end
end

end # module
