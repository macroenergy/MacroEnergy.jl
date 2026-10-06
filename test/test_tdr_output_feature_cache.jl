using CSV, DataFrames, MacroEnergy, Test

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
            "distributed" => true, "workers" => 2, "include_policy_constraints" => false,
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
