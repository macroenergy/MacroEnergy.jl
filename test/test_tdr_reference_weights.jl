module TestTDRReferenceWeights

using Test, CSV, DataFrames
import MacroEnergy as ME

function reference(commodity; included=true, weight=2.0, reason="explicitly_excluded")
    return (
        json_file="nodes.json", input_path=Any[commodity, "demand"],
        feature_id=reason == "no_matching_feature" && !included ? nothing : "demand",
        field="demand", asset=nothing, commodity=commodity, user_weight=weight,
        include_in_clustering=included, clustering_exclusion_reason=included ? nothing : reason,
    )
end

function shared_source(references)
    sources = Dict{String,ME.TimeSeriesSource}()
    for ref in references
        ME.tdr_add_reference!(sources, "shared", [1.,2.,3.,4.]; csv_path="profiles.csv", header=:shared, reference=ref)
    end
    return only(values(sources))
end

@testset "TDR included-reference weights" begin
    @testset "Inclusion flags and order control weight, not total uses" begin
        for flags in ((true,true), (true,false), (false,true), (false,false)),
            reason in ("explicitly_excluded", "no_matching_feature"), reversed in (false, true)
            references = [reference(name; included=flag, reason,
                weight=!flag && reason == "no_matching_feature" ? 1.0 : 2.0)
                for (name, flag) in zip(("Electricity", "Hydrogen"), flags)]
            reversed && reverse!(references)
            source = shared_source(references)
            @test source.occurrences == 2
            @test length(source.references) == 2
            @test source.weight == 2.0 * count(identity, flags)
            @test source.include_in_clustering == any(flags)
        end
    end

    @testset "Excluded weights do not conflict with included weights" begin
        for reversed in (false, true)
            references = [reference("Electricity"; weight=2.0), reference("Hydrogen"; included=false, weight=9.0)]
            reversed && reverse!(references)
            source = shared_source(references)
            @test source.weight == 2.0
            @test source.user_weight == 2.0
            @test source.occurrences == 2
            @test shared_source([reference("Electricity"; included=false, weight=2.0),
                reference("Hydrogen"; included=false, weight=9.0)]).weight == 0.0

            conflicting = [reference("Electricity"; weight=2.0), reference("Hydrogen"; weight=3.0)]
            reversed && reverse!(conflicting)
            @test_throws r"conflicting feature weights" shared_source(conflicting)
        end
    end

    @testset "Shared CSV reduction and clustering log counts" begin
        for excluded_count in 0:2, reversed in (false, true)
            mktempdir() do root
                source = joinpath(root, "source")
                mkpath(source)
                profile = [1.,2.,9.,10.,20.,21.]
                CSV.write(joinpath(source, "profiles.csv"), DataFrame(shared=profile, control=[0.,0.,1.,1.,2.,2.]))
                descriptor(header) = Dict("timeseries" => Dict("path" => "profiles.csv", "header" => header))
                nodes = Any[Dict("type" => name, "instance_data" => Dict("id" => name, "demand" => descriptor("shared")))
                    for name in ("Electricity", "Hydrogen")]
                reversed && reverse!(nodes)
                push!(nodes, Dict("type" => "Electricity", "instance_data" => Dict("id" => "control", "price" => descriptor("control"))))
                ME.write_json(joinpath(source, "system_data.json"), Dict("nodes" => nodes, "time_data" => Dict("path" => "time.json")))
                ME.write_json(joinpath(source, "time.json"), Dict(
                    "HoursPerTimeStep" => Dict("Electricity" => 1, "Hydrogen" => 1),
                    "HoursPerSubperiod" => Dict("Electricity" => 2, "Hydrogen" => 2),
                    "NumberOfSubperiods" => 3, "TotalHoursModeled" => 6))
                exclusions = [Dict("field" => "demand", "commodity" => name)
                    for name in ("Hydrogen", "Electricity")[1:excluded_count]]
                config = Dict("timesteps_per_representative_period" => 2, "representative_periods" => 1,
                    "method" => Dict("name" => "kmeans", "settings" => Dict("restarts" => 1)), "scaling" => "standardize",
                    "features" => [Dict("field" => "demand", "weight" => 3.0), Dict("field" => "price")], "exclude" => exclusions)
                settings = ME.load_tdr_settings_data(config)
                prepared = ME.tdr_prepare_inputs(source, [settings])
                series = only(filter(series -> series.header == :shared, only(prepared.systems).sources))
                included_count = 2 - excluded_count
                @test series.occurrences == 2
                @test series.weight == 3.0 * included_count
                @test series.include_in_clustering == (included_count > 0)

                original = read(joinpath(source, "profiles.csv"))
                config_path = joinpath(root, "tdr.json")
                ME.write_json(config_path, config)
                output = joinpath(root, "reduced")
                ME.preprocess_inputs(source, output; tdr_settings_path=config_path)
                representative = first(CSV.read(joinpath(output, "period_map.csv"), DataFrame).Rep_Period)
                rows = (representative - 1) * 2 .+ (1:2)
                @test CSV.read(joinpath(output, "profiles.csv"), DataFrame).shared == profile[rows]
                @test read(joinpath(source, "profiles.csv")) == original

                log = ME.read_json(joinpath(output, "preprocessing_logs", "preprocess_log.json"))[:time_domain_reduction]
                @test log[:discovered_time_series][:occurrences] == 3
                @test log[:clustering_features][:occurrences] == included_count + 1
                @test log[:clustering_features][:unique_time_series] == (included_count > 0 ? 2 : 1)
                logged = only(filter(entry -> entry[:source][:header] == "shared", log[:discovered_time_series][:sources]))
                @test logged[:occurrences] == 2
                @test logged[:weight] == 3.0 * included_count
                @test count(ref -> ref[:include_in_clustering], logged[:references]) == included_count
                @test logged[:reduced]
            end
        end
    end
end

end # module
