using CSV, DataFrames, MacroEnergy, Test

function candidate_test_settings(length, count=1; method="kmeans", outputs=false)
    data = Dict{String,Any}("timesteps_per_representative_period" => length,
        "representative_periods" => count, "method" => Dict("name" => method), "scaling" => "standardize")
    outputs && (data["output_based_features"] = Dict("weight" => 0.5,
        "features" => [Dict("provider" => "flow")]))
    return MacroEnergy.load_tdr_settings_data(data)
end

function write_candidate_fixture(root; length=5, count=2, values=Float64.(1:length*count), map=nothing)
    mkpath(root)
    time_data = Dict{String,Any}("HoursPerTimeStep" => Dict("Electricity" => 1),
        "HoursPerSubperiod" => Dict("Electricity" => length),
        "NumberOfSubperiods" => count, "TotalHoursModeled" => isnothing(map) ? length*count : length*nrow(map))
    if !isnothing(map)
        CSV.write(joinpath(root, "source_map.csv"), map)
        time_data["SubPeriodMap"] = Dict("path" => "source_map.csv")
    end
    MacroEnergy.write_json(joinpath(root, "time_data.json"), time_data)
    MacroEnergy.write_json(joinpath(root, "system_data.json"), Dict(
        "time_data" => Dict("path" => "time_data.json"), "nodes" => Dict("path" => "nodes.json")))
    MacroEnergy.write_json(joinpath(root, "nodes.json"), Dict(
        "demand" => Dict("timeseries" => Dict("path" => "demand.csv", "header" => "demand")),
        "availability" => values))
    CSV.write(joinpath(root, "demand.csv"), DataFrame(Time_Index=1:Base.length(values), demand=values))
    return time_data
end

@testset "shared TDR candidate periods" begin
    @testset "nested arrays in reusable subperiod inputs" begin
        mktempdir() do root
            source = joinpath(root, "source")
            write_candidate_fixture(source)
            nodes = MacroEnergy.mutable_json_data(MacroEnergy.read_json(joinpath(source, "nodes.json")))
            MacroEnergy.write_json(joinpath(source, "nodes.json"), Dict("nodes" => [nodes]))
            mkpath(joinpath(source, "user_additions"))
            MacroEnergy.write_json(joinpath(source, "user_additions", "metadata.json"), Dict("items" => ["shared", "addition"]))
            settings = candidate_test_settings(2; outputs=true)
            prepared = MacroEnergy.tdr_prepare_inputs(source, [settings])
            inputs = MacroEnergy.tdr_prepare_subperiod_inputs(only(prepared.systems))
            destination = joinpath(root, "isolated")
            MacroEnergy.tdr_materialize_subperiod_case!(inputs, destination, 2, settings)
            @test only(MacroEnergy.read_json(joinpath(destination, "nodes.json"))["nodes"])["availability"] == [3, 4]
            @test MacroEnergy.read_json(joinpath(destination, "user_additions", "metadata.json"))["items"] == ["shared", "addition"]
        end
    end

    mktempdir() do root
        source = joinpath(root, "source")
        time_data = write_candidate_fixture(source)
        settings = candidate_test_settings(2)
        candidates = MacroEnergy.tdr_build_candidate_periods(time_data, source, settings)
        @test candidates.ranges == [1:2, 3:4, 6:7, 8:9]
        @test candidates.weights == ones(Int, 4)
        @test candidates.occurrence_map == collect(1:4)
        @test MacroEnergy.tdr_candidate_rows(candidates) == [1, 2, 3, 4, 6, 7, 8, 9]
        summary = MacroEnergy.tdr_candidate_summary(candidates)
        @test summary["trimmed_stored_hours"] == 2
        @test summary["trimmed_represented_hours"] == 2
        @test_throws ArgumentError MacroEnergy.tdr_build_candidate_periods(time_data, source, candidate_test_settings(6))

        output_settings = candidate_test_settings(2; outputs=true)
        isolated = joinpath(root, "isolated")
        prepared = MacroEnergy.tdr_prepare_inputs(source, [output_settings])
        subperiod_inputs = MacroEnergy.tdr_prepare_subperiod_inputs(only(prepared.systems))
        MacroEnergy.tdr_materialize_subperiod_case!(subperiod_inputs, isolated, 3, output_settings)
        @test CSV.read(joinpath(isolated, "demand.csv"), DataFrame).demand == [6, 7]
        isolated_time = MacroEnergy.read_json(joinpath(isolated, "time_data.json"))
        @test isolated_time["HoursPerSubperiod"]["Electricity"] == 2
        @test isolated_time["NumberOfSubperiods"] == 1
        @test !haskey(isolated_time, "SubPeriodMap")
        @test MacroEnergy.read_json(joinpath(isolated, "nodes.json"))["availability"] == [6, 7]
        # Reusing the snapshot must not carry the first isolated case's slicing
        # or time settings into the next candidate or back into the source.
        second_isolated = joinpath(root, "second_isolated")
        MacroEnergy.tdr_materialize_subperiod_case!(subperiod_inputs, second_isolated, 1, output_settings)
        @test CSV.read(joinpath(second_isolated, "demand.csv"), DataFrame).demand == [1, 2]
        @test MacroEnergy.read_json(joinpath(second_isolated, "nodes.json"))["availability"] == [1, 2]
        @test MacroEnergy.read_json(joinpath(source, "time_data.json"))["HoursPerSubperiod"]["Electricity"] == 5
        original_definition = read(joinpath(source, "system_data.json"), String)
        @test_throws ArgumentError time_domain_reduction(source, [output_settings, output_settings])
        @test read(joinpath(source, "system_data.json"), String) == original_definition

        output = joinpath(root, "reduced")
        settings_path = joinpath(root, "settings.json")
        MacroEnergy.write_json(settings_path, Dict("timesteps_per_representative_period" => 2,
            "representative_periods" => 2, "method" => Dict("name" => "kmeans"), "scaling" => "standardize"))
        preprocess_inputs(source, output; tdr_settings_path=settings_path)
        reduced_time = MacroEnergy.read_json(joinpath(output, "time_data.json"))
        @test reduced_time["HoursPerSubperiod"]["Electricity"] == 2
        @test reduced_time["NumberOfSubperiods"] == 2
        @test reduced_time["TotalHoursModeled"] == 10
        frame = CSV.read(joinpath(output, "demand.csv"), DataFrame)
        @test nrow(frame) == 4
        @test all(value -> value ∉ (5, 10), frame.demand)
        @test frame.Time_Index == 1:4
        @test MacroEnergy.read_json(joinpath(output, "nodes.json"))["availability"] == frame.demand
        @test nrow(CSV.read(joinpath(output, "period_map.csv"), DataFrame)) == 4
        temporal = MacroEnergy.read_json(joinpath(output, "preprocessing_logs", "preprocess_log.json"))["time_domain_reduction"]["temporal_summary"]
        @test temporal["candidate_periods"] == 4
        @test temporal["trimmed_stored_hours"] == 2
        loaded = MacroEnergy.load_time_data(joinpath(output, "time_data.json"),
            Dict{Symbol,DataType}(:Electricity => MacroEnergy.Electricity), output)
        timedata = loaded[:Electricity]
        @test length(timedata.time_interval) == 4
        @test sum(values(timedata.subperiod_weights)) * 2 ≈ 10
        @test CSV.read(joinpath(source, "demand.csv"), DataFrame).demand == 1:10

        # Invalid longer periods must not replace an existing destination.
        write(joinpath(output, "marker"), "keep")
        MacroEnergy.write_json(settings_path, Dict("timesteps_per_representative_period" => 6,
            "representative_periods" => 1, "method" => Dict("name" => "kmeans"), "scaling" => "standardize"))
        @test_throws ArgumentError preprocess_inputs(source, output; tdr_settings_path=settings_path, overwrite=true)
        @test read(joinpath(output, "marker"), String) == "keep"
    end

    @testset "recast chronology and inherited weights" begin
        mktempdir() do root
            map = DataFrame(Period_Index=[3, 1, 2, 4], Rep_Period=[2, 1, 2, 2], Rep_Period_Index=[2, 1, 2, 2])
            time_data = write_candidate_fixture(root; map)
            candidates = MacroEnergy.tdr_build_candidate_periods(time_data, root, candidate_test_settings(2))
            @test candidates.source_occurrences == [1, 2, 2, 2]
            @test candidates.weights == [1, 1, 3, 3]
            @test candidates.occurrence_map == [1, 2, 3, 4, 3, 4, 3, 4]
            @test MacroEnergy.tdr_candidate_summary(candidates)["trimmed_represented_hours"] == 4
            recast = MacroEnergy.tdr_compose_period_map(candidates, [1, 3], [1, 1, 2, 2])
            @test recast.Period_Index == 1:8
            @test recast.Rep_Period == [1, 1, 3, 3, 3, 3, 3, 3]
            @test recast.Rep_Period_Index == [1, 1, 2, 2, 2, 2, 2, 2]
            @test MacroEnergy.tdr_weighted_candidates(collect(1:4), [2, 2, 6, 6]) ==
                [1, 2, 3, 3, 3, 4, 4, 4]
            @test MacroEnergy.tdr_weighted_candidates(collect(1:4), fill(7, 4)) == collect(1:4)

            same = MacroEnergy.tdr_build_candidate_periods(time_data, root, candidate_test_settings(5))
            @test same.weights == [1, 3]
            @test same.occurrence_map == [1, 2, 2, 2]
            @test same.trimmed_hours_per_source_period == 0
            weekly = deepcopy(time_data)
            weekly["HoursPerSubperiod"]["Electricity"] = 168
            weekly["TotalHoursModeled"] = 672
            split_weeks = MacroEnergy.tdr_build_candidate_periods(weekly, root, candidate_test_settings(20))
            @test length(split_weeks.ranges) == 16
            @test split_weeks.ranges[9] == 169:188
            @test split_weeks.weights == vcat(fill(1, 8), fill(3, 8))
            @test MacroEnergy.tdr_candidate_summary(split_weeks)["trimmed_stored_hours"] == 16
            @test MacroEnergy.tdr_candidate_summary(split_weeks)["trimmed_represented_hours"] == 32
            @test_throws ArgumentError MacroEnergy.tdr_build_candidate_periods(weekly, root, candidate_test_settings(169))
            year = deepcopy(time_data)
            pop!(year, "SubPeriodMap")
            year["HoursPerSubperiod"]["Electricity"] = 8760
            year["NumberOfSubperiods"] = 1
            year["TotalHoursModeled"] = 8760
            split_year = MacroEnergy.tdr_build_candidate_periods(year, root, candidate_test_settings(168))
            @test length(split_year.ranges) == 52
            @test split_year.trimmed_hours_per_source_period == 24
            @test last(split_year.ranges) == 8569:8736
            multiple = deepcopy(time_data)
            multiple["HoursPerSubperiod"]["CO2"] = 5
            multiple["HoursPerTimeStep"]["CO2"] = 1
            updated = MacroEnergy.tdr_reduced_time_data(multiple, 2, 3)
            @test all(==(2), values(updated["HoursPerSubperiod"]))
            @test updated["NumberOfSubperiods"] == 3
            @test updated["TotalHoursModeled"] == multiple["TotalHoursModeled"]
            @test multiple["HoursPerSubperiod"]["CO2"] == 5
            malformed = deepcopy(time_data)
            CSV.write(joinpath(root, "bad_map.csv"), DataFrame(Period_Index=[1, 1], Rep_Period=[1, 2], Rep_Period_Index=[1, 2]))
            malformed["SubPeriodMap"] = Dict("path" => "bad_map.csv")
            @test_throws ArgumentError MacroEnergy.tdr_build_candidate_periods(malformed, root, candidate_test_settings(2))
            CSV.write(joinpath(root, "source_map.csv"), DataFrame(Period_Index=1:4,
                Rep_Period=[2, 2, 4, 4], Rep_Period_Index=[1, 1, 2, 2]))
            anchored = MacroEnergy.tdr_build_candidate_periods(time_data, root, candidate_test_settings(2))
            @test anchored.labels == [3, 4, 7, 8]
            anchored_map = MacroEnergy.tdr_compose_period_map(anchored, [1, 3], [1, 1, 2, 2])
            @test anchored_map.Rep_Period == [3, 3, 3, 3, 7, 7, 7, 7]
            @test anchored_map.Rep_Period[3] == 3
            @test anchored_map.Rep_Period[7] == 7
        end
    end

    @testset "occurrence weights influence selection" begin
        source = MacroEnergy.TimeSeriesSource("demand", nothing, nothing, nothing, Any[],
            [0.0, 10.0], 1, NamedTuple[], 1, 1.0, 1.0, true)
        for method in ("kmeans", "kmedoids")
            settings = candidate_test_settings(1; method)
            representatives, assignments = MacroEnergy.tdr_cluster([source], 2, settings; candidate_weights=[1, 9])
            @test representatives == [2]
            @test assignments == [1, 1]
            representatives, _ = MacroEnergy.tdr_cluster([source], 2, settings; candidate_weights=[9, 1])
            @test representatives == [1]
        end
        @test MacroEnergy.tdr_scale([0.0, 10.0], :standardize; period_weights=[1, 9]) ≈ [-3.0, 1/3]
        @test_throws ArgumentError MacroEnergy.tdr_cluster([source], 2, candidate_test_settings(1); candidate_weights=[0, 1])
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
            representatives, assignments = MacroEnergy.tdr_cluster([profiles], 6, settings; candidate_weights=[3, 1, 1])
            @test length(representatives) == 2
            @test allunique(representatives)
            @test length(assignments) == 3
            @test Set(assignments) == Set((1, 2))
        end
    end

    @testset "repeated clustering preserves frequencies" begin
        mktempdir() do root
            source = joinpath(root, "source")
            first_output = joinpath(root, "first")
            second_output = joinpath(root, "second")
            map = DataFrame(Period_Index=1:4, Rep_Period=[1, 2, 2, 2], Rep_Period_Index=[1, 2, 2, 2])
            write_candidate_fixture(source; length=4, map, values=[1., 2, 3, 4, 10, 20, 30, 40])
            first_settings = joinpath(root, "first.json")
            MacroEnergy.write_json(first_settings, Dict("timesteps_per_representative_period" => 2,
                "representative_periods" => 4, "method" => Dict("name" => "kmeans"), "scaling" => "standardize"))
            preprocess_inputs(source, first_output; tdr_settings_path=first_settings)
            first_map = CSV.read(joinpath(first_output, "period_map.csv"), DataFrame)
            @test first_map.Period_Index == 1:8
            @test first_map.Rep_Period_Index == [1, 2, 3, 4, 3, 4, 3, 4]
            second_settings = joinpath(root, "second.json")
            MacroEnergy.write_json(second_settings, Dict("timesteps_per_representative_period" => 1,
                "representative_periods" => 2, "method" => Dict("name" => "kmeans"), "scaling" => "standardize"))
            preprocess_inputs(first_output, second_output; tdr_settings_path=second_settings)
            second_map = CSV.read(joinpath(second_output, "period_map.csv"), DataFrame)
            @test second_map.Period_Index == 1:16
            @test length(unique(second_map.Rep_Period_Index)) == 2
            second_time = MacroEnergy.read_json(joinpath(second_output, "time_data.json"))
            @test second_time["HoursPerSubperiod"]["Electricity"] == 1
            @test second_time["NumberOfSubperiods"] == 2
            @test second_time["TotalHoursModeled"] == 16
        end
    end

    @testset "annual source to weekly representatives" begin
        mktempdir() do root
            source = joinpath(root, "annual")
            output = joinpath(root, "weekly")
            write_candidate_fixture(source; length=8760, count=1)
            settings_path = joinpath(root, "weekly.json")
            MacroEnergy.write_json(settings_path, Dict("timesteps_per_representative_period" => 168,
                "representative_periods" => 2, "method" => Dict("name" => "kmeans"), "scaling" => "standardize"))
            preprocess_inputs(source, output; tdr_settings_path=settings_path)
            time_data = MacroEnergy.read_json(joinpath(output, "time_data.json"))
            @test time_data["HoursPerSubperiod"]["Electricity"] == 168
            @test time_data["NumberOfSubperiods"] == 2
            @test time_data["TotalHoursModeled"] == 8760
            @test nrow(CSV.read(joinpath(output, "demand.csv"), DataFrame)) == 336
            @test nrow(CSV.read(joinpath(output, "period_map.csv"), DataFrame)) == 52
            temporal = MacroEnergy.read_json(joinpath(output, "preprocessing_logs", "preprocess_log.json"))["time_domain_reduction"]["temporal_summary"]
            @test temporal["trimmed_stored_hours"] == 24
            @test temporal["trimmed_represented_hours"] == 24
            loaded = MacroEnergy.load_time_data(joinpath(output, "time_data.json"),
                Dict{Symbol,DataType}(:Electricity => MacroEnergy.Electricity), output)
            @test length(loaded[:Electricity].time_interval) == 336
        end
    end
end
