module TestUserAdditions
"""
Tests for user-defined commodity additions and persistence behavior.

These tests verify that custom subcommodity definitions:
- resolve correctly when listed out of order,
- fail fast on circular parent dependencies,
- are written to file deterministically without duplicates.
"""

using Test

import MacroEnergy

import MacroEnergy:
    all_subtypes,
    load_commodities,
    commodity_types,
    Commodity,
    register_commodity_types!,
    create_user_additions_module,
    load_user_additions,
    user_additions_path,
    user_additions_assets_dir,
    write_user_commodities,
    user_additions_commodities_path

"""
Generate a unique symbol for dynamically-defined test commodity types.

Using unique names avoids collisions with prior test runs in the same Julia session.
"""
function unique_test_symbol(prefix::AbstractString)
    return Symbol("$(prefix)_$(time_ns())")
end

"""
Verify that chained user-defined subcommodities resolve correctly even when inputs are out of order.

Expected behavior:
- parent type is created first through iterative resolution,
- child types are then created and registered,
- resulting type hierarchy matches parent-child declarations.
"""
function test_chained_subcommodities_out_of_order()
    register_commodity_types!()

    diesel = unique_test_symbol("TestDiesel")
    clean_diesel = unique_test_symbol("TestCleanDiesel")
    dirty_diesel = unique_test_symbol("TestDirtyDiesel")

    commodities = Any[
        Dict{Symbol,Any}(:name => String(clean_diesel), :acts_like => String(diesel)),
        Dict{Symbol,Any}(:name => String(dirty_diesel), :acts_like => String(diesel)),
        Dict{Symbol,Any}(:name => String(diesel), :acts_like => "LiquidFuels"),
    ]

    loaded = load_commodities(commodities, ""; write_subcommodities=false)
    macro_commodities = commodity_types()
    liquid_fuels = macro_commodities[:LiquidFuels]

    @test haskey(loaded, diesel)
    @test haskey(loaded, clean_diesel)
    @test haskey(loaded, dirty_diesel)

    @test macro_commodities[diesel] <: liquid_fuels
    @test macro_commodities[clean_diesel] <: macro_commodities[diesel]
    @test macro_commodities[dirty_diesel] <: macro_commodities[diesel]
end

"""
Verify that unknown plain commodity names are interpreted as top-level user commodities.

Expected behavior:
- unknown string/symbol commodity entries are created as `<: Commodity`,
- subcommodities can inherit from those newly created top-level commodities.
"""
function test_implicit_top_level_commodities()
    register_commodity_types!()

    top_level = unique_test_symbol("TestTopLevel")
    child = unique_test_symbol("TestTopLevelChild")

    commodities = Any[
        "Electricity",
        String(top_level),
        Dict{Symbol,Any}(:name => String(child), :acts_like => String(top_level)),
    ]

    loaded = load_commodities(commodities, ""; write_subcommodities=false)
    macro_commodities = commodity_types()

    @test haskey(loaded, top_level)
    @test haskey(loaded, child)
    @test macro_commodities[top_level] <: Commodity
    @test macro_commodities[child] <: macro_commodities[top_level]

    symbol_top_level = unique_test_symbol("TestTopLevelSymbol")
    loaded_symbols = load_commodities(Any[symbol_top_level], ""; write_subcommodities=false)
    @test haskey(loaded_symbols, symbol_top_level)
    @test commodity_types()[symbol_top_level] <: Commodity
end

"""
Verify strict mode rejects unknown plain commodities.

Expected behavior:
- when implicit top-level commodity creation is disabled,
- unknown commodity names throw the legacy unknown-commodity error.
"""
function test_disallow_implicit_top_level_commodities()
    register_commodity_types!()

    unknown_commodity = unique_test_symbol("TestStrictUnknown")
    commodities = Any[String(unknown_commodity)]

    @test_throws "Unknown commodity" load_commodities(
        commodities,
        "";
        write_subcommodities=false,
        allow_implicit_top_level_commodities=false,
    )
end

"""
Verify that circular subcommodity dependencies are rejected with a clear error.

Expected behavior:
- no subtype definitions are applied for unresolved cycles,
- loader throws an informative error about unknown/circular parents.
"""
function test_circular_subcommodities_error()
    register_commodity_types!()

    commodity_a = unique_test_symbol("TestCommodityA")
    commodity_b = unique_test_symbol("TestCommodityB")

    commodities = Any[
        Dict{Symbol,Any}(:name => String(commodity_a), :acts_like => String(commodity_b)),
        Dict{Symbol,Any}(:name => String(commodity_b), :acts_like => String(commodity_a)),
    ]

    @test_throws "Unknown or circular parent commodities" load_commodities(commodities, ""; write_subcommodities=false)
end

"""
Verify `all_subtypes(MacroEnergy, :Commodity)` includes user-defined top-level commodities and subcommodities.

Expected behavior:
- newly created top-level user commodities appear in all_subtypes output,
- user subcommodities also appear,
- discovered subtype hierarchy matches the declared parent relationships.
"""
function test_all_subtypes_includes_user_commodities()
    register_commodity_types!()

    top_level_a = unique_test_symbol("TestSubtypeTopLevelA")
    top_level_b = unique_test_symbol("TestSubtypeTopLevelB")
    child_a = unique_test_symbol("TestSubtypeChildA")
    child_b = unique_test_symbol("TestSubtypeChildB")

    commodities = Any[
        String(top_level_a),
        Symbol(top_level_b),
        Dict{Symbol,Any}(:name => String(child_a), :acts_like => String(top_level_a)),
        Dict{Symbol,Any}(:name => String(child_b), :acts_like => String(top_level_b)),
    ]

    load_commodities(commodities, ""; write_subcommodities=false)

    all_commodity_subtypes = Base.invokelatest(all_subtypes, MacroEnergy, :Commodity)

    @test haskey(all_commodity_subtypes, top_level_a)
    @test haskey(all_commodity_subtypes, top_level_b)
    @test haskey(all_commodity_subtypes, child_a)
    @test haskey(all_commodity_subtypes, child_b)

    @test all_commodity_subtypes[top_level_a] <: Commodity
    @test all_commodity_subtypes[top_level_b] <: Commodity
    @test all_commodity_subtypes[child_a] <: all_commodity_subtypes[top_level_a]
    @test all_commodity_subtypes[child_b] <: all_commodity_subtypes[top_level_b]
end

"""
Verify deterministic and de-duplicated persistence of generated subcommodity lines.

Expected behavior:
- existing file order is preserved,
- duplicate and blank lines are ignored,
- only new unique definitions are appended.
"""
function test_subcommodities_file_write_order()
    case_path = mktempdir()

    write_user_commodities(case_path, [
        "abstract type TestA <: MacroEnergy.LiquidFuels end",
        "abstract type TestB <: MacroEnergy.LiquidFuels end",
        "abstract type TestA <: MacroEnergy.LiquidFuels end",
    ])

    write_user_commodities(case_path, [
        "",
        "abstract type TestB <: MacroEnergy.LiquidFuels end",
        "abstract type TestC <: MacroEnergy.LiquidFuels end",
    ])

    lines = readlines(user_additions_commodities_path(case_path))
    @test lines == [
        "abstract type TestA <: MacroEnergy.LiquidFuels end",
        "abstract type TestB <: MacroEnergy.LiquidFuels end",
        "abstract type TestC <: MacroEnergy.LiquidFuels end",
    ]
end

"""
Verify that persisted subcommodity definitions are dependency ordered.

Expected behavior:
- if a child line is seen before its parent line,
- writer rewrites file so parent definition appears first.
"""
function test_subcommodities_dependency_write_order()
    case_path = mktempdir()

    write_user_commodities(case_path, [
        "abstract type TestChildFuel <: MacroEnergy.TestParentFuel end",
        "abstract type TestParentFuel <: MacroEnergy.LiquidFuels end",
    ])

    lines = readlines(user_additions_commodities_path(case_path))
    @test lines == [
        "abstract type TestParentFuel <: MacroEnergy.LiquidFuels end",
        "abstract type TestChildFuel <: MacroEnergy.TestParentFuel end",
    ]
end

"""
Verify user-defined assets are loaded into MacroEnergy scope.

Expected behavior:
- `userassets.jl` can reference `System` unqualified,
- custom asset type is defined in `MacroEnergy`, not only in `UserAdditions`.
"""
function test_user_asset_load_scope()
    case_path = mktempdir()
    asset_name_a = unique_test_symbol("TestUserAssetA")
    asset_name_b = unique_test_symbol("TestUserAssetB")
    assets_dir = user_additions_assets_dir(case_path)
    mkpath(assets_dir)

    open(joinpath(assets_dir, "asset_a.jl"), "w") do io
        println(io, "struct $(asset_name_a) <: AbstractAsset end")
        println(io, "make(::Type{<:$(asset_name_a)}, data::AbstractDict{Symbol,Any}, system::System) = nothing")
    end

    open(joinpath(assets_dir, "asset_b.jl"), "w") do io
        println(io, "struct $(asset_name_b) <: AbstractAsset end")
        println(io, "make(::Type{<:$(asset_name_b)}, data::AbstractDict{Symbol,Any}, system::System) = nothing")
    end

    create_user_additions_module(case_path)
    load_user_additions(case_path)

    macroenergy_module = parentmodule(load_commodities)
    @test isdefined(macroenergy_module, asset_name_a)
    @test isdefined(macroenergy_module, asset_name_b)
end

"""
Verify both userassets.jl and assets/*.jl are loaded when both are present.
"""
function test_user_asset_file_and_folder_load_together()
    case_path = mktempdir()
    asset_name_single = unique_test_symbol("TestUserAssetSingle")
    asset_name_folder = unique_test_symbol("TestUserAssetFolder")

    single_asset_path = joinpath(user_additions_path(case_path), "userassets.jl")
    assets_dir = user_additions_assets_dir(case_path)
    mkpath(dirname(single_asset_path))
    mkpath(assets_dir)

    open(single_asset_path, "w") do io
        println(io, "struct $(asset_name_single) <: AbstractAsset end")
        println(io, "make(::Type{<:$(asset_name_single)}, data::AbstractDict{Symbol,Any}, system::System) = nothing")
    end

    open(joinpath(assets_dir, "asset_folder.jl"), "w") do io
        println(io, "struct $(asset_name_folder) <: AbstractAsset end")
        println(io, "make(::Type{<:$(asset_name_folder)}, data::AbstractDict{Symbol,Any}, system::System) = nothing")
    end

    create_user_additions_module(case_path)
    load_user_additions(case_path)

    macroenergy_module = parentmodule(load_commodities)
    @test isdefined(macroenergy_module, asset_name_single)
    @test isdefined(macroenergy_module, asset_name_folder)
end

"""
Run all user additions tests.
"""
function test_user_additions()
    @testset "Chained subcommodities" begin
        test_chained_subcommodities_out_of_order()
    end

    @testset "Circular dependency handling" begin
        test_circular_subcommodities_error()
    end

    @testset "Implicit top-level commodities" begin
        test_implicit_top_level_commodities()
    end

    @testset "all_subtypes with user commodities" begin
        test_all_subtypes_includes_user_commodities()
    end

    @testset "Strict top-level commodity mode" begin
        test_disallow_implicit_top_level_commodities()
    end

    @testset "Deterministic subcommodity writes" begin
        test_subcommodities_file_write_order()
    end

    @testset "Dependency-ordered subcommodity writes" begin
        test_subcommodities_dependency_write_order()
    end

    @testset "User asset loading scope" begin
        test_user_asset_load_scope()
    end

    @testset "User asset file+folder loading" begin
        test_user_asset_file_and_folder_load_together()
    end

    return nothing
end

test_user_additions()

end # module TestUserAdditions
