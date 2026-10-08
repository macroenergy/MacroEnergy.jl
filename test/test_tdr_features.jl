using MacroEnergy, Test

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
            "field" => "availability", "weight" => 2))
        @test length(availability(overridden)) == 1
        @test generic(overridden).asset == "ThermalPower"
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

@testset "Explicit feature override scope" begin
    scoped_feature = MacroEnergy.tdr_feature_spec(Dict(
        "id" => "availability",
        "field" => "availability",
        "asset" => "VRE",
        "commodity" => "Electricity",
        "weight" => 2.0,
    ))
    merged_features = MacroEnergy.tdr_merge_features([scoped_feature])
    merged_availability = only(filter(feature -> feature.id == "availability", merged_features))
    @test merged_availability.asset == "VRE"
    @test merged_availability.commodity == "Electricity"
    @test merged_availability.user_weight == 2.0
end
