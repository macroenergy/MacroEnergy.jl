using MacroEnergy, Test, CSV, DataFrames

@testset "TDR feature additions and explicit overrides" begin
    spec(data) = MacroEnergy.tdr_feature_spec(data)
    merge_specs(data...) = MacroEnergy.tdr_merge_features(MacroEnergy.TDRFeatureSpec[spec(item) for item in data])
    availability(features) = filter(feature -> feature.field == "availability", features)
    generic(features) = only(filter(feature -> feature.id == "availability", features))
    mktempdir() do root
        select(features, asset, commodity="Electricity") = MacroEnergy.tdr_feature_for_reference(
            features, "availability", joinpath(root, "assets.json"), nothing, root, asset, commodity)

        # The user's examples: a scoped addition versus a deliberate ID override.
        added = merge_specs(Dict("asset" => "ThermalPower", "field" => "availability", "weight" => 2))
        @test length(availability(added)) == 2
        @test isnothing(generic(added).asset) && generic(added).user_weight == 1
        @test select(added, "ThermalPower").user_weight == 2
        @test select(added, "VRE").user_weight == 1
        overridden = merge_specs(Dict("id" => "availability", "asset" => "ThermalPower",
            "field" => "availability", "commodity" => "Electricity", "weight" => 2))
        @test length(availability(overridden)) == 1
        @test generic(overridden).asset == "ThermalPower" && generic(overridden).commodity == "Electricity"
        @test select(overridden, "ThermalPower").user_weight == 2
        @test isnothing(select(overridden, "VRE"))

        scoped = merge_specs(
            Dict("field" => "availability", "asset" => "VRE", "weight" => 3),
            Dict("field" => "availability", "asset" => "Hydro", "weight" => 2))
        @test length(availability(scoped)) == 3
        @test select(scoped, "VRE").user_weight == 3
        @test select(scoped, "Hydro").user_weight == 2
        @test select(scoped, "ThermalPower").user_weight == 1
        @test isnothing(generic(scoped).asset)

        # Separate asset/commodity scopes must not become a hybrid selector.
        separate = merge_specs(
            Dict("field" => "availability", "commodity" => "Electricity", "weight" => 3),
            Dict("field" => "availability", "asset" => "Hydro"))
        @test length(availability(separate)) == 3
        hydro = only(filter(feature -> feature.asset == "Hydro", separate))
        electricity = only(filter(feature -> feature.commodity == "Electricity", separate))
        @test isnothing(hydro.commodity) && hydro.user_weight == 1
        @test isnothing(electricity.asset) && electricity.user_weight == 3
        @test select(separate, "Hydro", "Water") === hydro
        @test select(separate, "VRE") === electricity
        @test_throws ArgumentError select(separate, "Hydro")

        named = merge_specs(
            Dict("id" => "vre_av", "field" => "availability", "asset" => "VRE", "weight" => 3),
            Dict("field" => "availability", "asset" => "Hydro", "weight" => 2))
        @test length(availability(named)) == 3
        @test select(named, "VRE").id == "vre_av"
        @test select(named, "Hydro").user_weight == 2

        # No-ID overrides need exact selector equality, including omitted values.
        weighted = merge_specs(Dict("field" => "availability", "weight" => 4))
        @test length(availability(weighted)) == 1
        @test generic(weighted).id == "availability" && generic(weighted).user_weight == 4
        repeated = merge_specs(
            Dict("field" => "availability", "asset" => "VRE", "weight" => 3),
            Dict("field" => "availability", "asset" => "VRE", "weight" => 5),
            Dict("field" => "availability", "asset" => "VRE"))
        @test length(availability(repeated)) == 2
        @test select(repeated, "VRE").user_weight == 5
        files = merge_specs(
            Dict("field" => "availability", "file" => "data/one.csv", "weight" => 2),
            Dict("field" => "availability", "file" => "data/two.csv", "weight" => 3),
            Dict("field" => "availability", "file" => "data\\one.csv", "weight" => 4))
        @test length(availability(files)) == 3
        @test only(filter(feature -> feature.file == "data/one.csv", files)).user_weight == 4
        @test only(filter(feature -> feature.file == "data/two.csv", files)).user_weight == 3

        # IDs are the identity even when the field/file/scope changes; omitted
        # values preserve the existing feature's settings and weight.
        changed = merge_specs(Dict("id" => "availability", "field" => "custom_profile",
            "file" => "data/custom.csv", "asset" => "Hydro", "weight" => 6))
        @test isempty(availability(changed))
        replacement = generic(changed)
        @test replacement.field == "custom_profile" && replacement.file == "data/custom.csv"
        @test replacement.asset == "Hydro" && replacement.user_weight == 6
        inherited = merge_specs(
            Dict("id" => "availability", "field" => "availability", "asset" => "VRE", "weight" => 3),
            Dict("id" => "availability", "field" => "availability", "commodity" => "Electricity"))
        @test generic(inherited).asset == "VRE" && generic(inherited).commodity == "Electricity"
        @test generic(inherited).user_weight == 3

        ambiguous = merge_specs(Dict("id" => "duplicate", "field" => "availability"))
        @test_throws ArgumentError select(ambiguous, "VRE")
        @test_throws ArgumentError merge_specs(
            Dict("id" => "duplicate", "field" => "availability"), Dict("field" => "availability", "weight" => 2))
    end
end

@testset "TDR reference context and selector matching" begin
    ME = MacroEnergy
    mktempdir() do root
        input_file = joinpath(root, "assets.json")
        csv_file = joinpath(root, "profiles.csv")
        CSV.write(csv_file, DataFrame(profile=[1., 2., 3., 4.]))
        generic = ME.TDRFeatureSpec(id="availability_default", field="availability")
        context = ME.TDRContext(; input_file, csv_file, field="availability",
            asset="VRE", commodity="Electricity")
        match(selector; feature=generic, reference=context) =
            ME.tdr_reference_matches_selector(reference, selector, feature, root)

        # Feature ID belongs to the selected definition; the remaining fields
        # describe the actual reference even when its selected feature is generic.
        for selector in (
            ME.TDRFeatureSpec(id="availability_default"),
            ME.TDRFeatureSpec(field="availability"),
            ME.TDRFeatureSpec(file="assets.json"),
            ME.TDRFeatureSpec(file="profiles.csv"),
            ME.TDRFeatureSpec(asset="VRE"),
            ME.TDRFeatureSpec(commodity="Electricity"),
            ME.TDRFeatureSpec(id="availability_default", file="profiles.csv",
                field="availability", asset="VRE", commodity="Electricity"),
        )
            @test match(selector)
        end
        for selector in (
            ME.TDRFeatureSpec(id="other"), ME.TDRFeatureSpec(field="demand"),
            ME.TDRFeatureSpec(file="other.csv"), ME.TDRFeatureSpec(asset="Hydro"),
            ME.TDRFeatureSpec(commodity="Hydrogen"),
            ME.TDRFeatureSpec(asset="VRE", commodity="Hydrogen"),
        )
            @test !match(selector)
        end
        @test !match(ME.TDRFeatureSpec(id="availability_default"); feature=nothing)
        @test match(ME.TDRFeatureSpec(file="assets.json", asset="VRE"); feature=nothing)
        @test !ME.tdr_feature_matches_selector(generic, ME.TDRFeatureSpec(asset="VRE"))
        @test match(ME.TDRFeatureSpec(asset="VRE"))
        inline = ME.tdr_child_context(context; csv_file=nothing)
        @test match(ME.TDRFeatureSpec(file="assets.json"); reference=inline)
        @test !match(ME.TDRFeatureSpec(file="profiles.csv"); reference=inline)

        # Selection still uses existing specificity and detects ties.
        asset_feature = ME.TDRFeatureSpec(field="availability", asset="VRE", user_weight=3.0)
        file_feature = ME.TDRFeatureSpec(field="availability", file="profiles.csv", user_weight=4.0)
        most_specific = ME.TDRFeatureSpec(field="availability", file="assets.json",
            asset="VRE", commodity="Electricity", user_weight=7.0)
        @test ME.tdr_feature_for_reference([generic, asset_feature, most_specific], context, root) === most_specific
        @test_throws ArgumentError ME.tdr_feature_for_reference([asset_feature, file_feature], context, root)

        # Distinct references to one CSV column keep their own context and exclusions.
        descriptor = Dict("timeseries"=>Dict("path"=>"profiles.csv", "header"=>"profile"))
        raw = Dict("assets"=>[
            Dict("type"=>"VRE", "commodity"=>"Electricity", "availability"=>descriptor),
            Dict("type"=>"Hydro", "commodity"=>"Hydrogen", "availability"=>descriptor),
        ])
        for file in ("assets.json", "profiles.csv")
            sources = Dict{String,ME.TimeSeriesSource}()
            ME.tdr_collect_references!(sources, raw, input_file, root, 4, 4, Ref(0),
                [generic], [ME.TDRFeatureSpec(id="availability_default", asset="VRE", file=file)],
                Set(["Electricity", "Hydrogen"]))
            series = only(values(sources))
            by_asset = Dict(reference.asset => reference for reference in series.references)
            @test Set(keys(by_asset)) == Set(["VRE", "Hydro"])
            @test by_asset["VRE"].commodity == "Electricity"
            @test by_asset["Hydro"].commodity == "Hydrogen"
            @test !by_asset["VRE"].include_in_clustering
            @test by_asset["VRE"].clustering_exclusion_reason == "explicitly_excluded"
            @test by_asset["Hydro"].include_in_clustering
            @test series.include_in_clustering
            @test length(series.references) == 2
        end
    end
end
