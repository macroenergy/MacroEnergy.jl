module TestAssetElectrolyzerBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    Electricity,
    Electrolyzer,
    Hydrogen,
    flow,
    make

function make_electrolyzer_case(style::Symbol)
    system = make_test_system([Electricity, Hydrogen])
    elec_timedata = system.time_data[:Electricity]
    h2_timedata = system.time_data[:Hydrogen]

    elec_source = make_supply_node(Electricity, :elec_source, elec_timedata, [1.0, 1.0, 1.0])
    h2_sink = make_demand_node(Hydrogen, :h2_sink, h2_timedata, [2.0, 4.0, 6.0])
    push_locations!(system, elec_source, h2_sink)

    asset = make(
        Electrolyzer,
        Dict{Symbol,Any}(
            :id => :electrolyzer_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 20.0,
            :efficiency_rate => 0.5,
            :elec_start_vertex => :elec_source,
            :h2_end_vertex => :h2_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.electrolyzer_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :energy, flow(asset.h2_edge) == 0.5 * flow(asset.elec_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :energy,
            flow(asset.elec_edge) --> 0.5 * flow(asset.h2_edge),
            flow(asset.h2_edge),
        )
    else
        error("Unsupported electrolyzer balance style: $style")
    end

    return (; system, asset)
end

function assert_electrolyzer_solution(asset, model)
    expected_h2 = [2.0, 4.0, 6.0]
    expected_elec = [4.0, 8.0, 12.0]

    @test objective_value(model) ≈ 24.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.h2_edge, t)) ≈ expected_h2[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
    end
end

function test_asset_electrolyzer_balance()
    @testset "Electrolyzer Small Solve Cases" begin
        add_balance_case = make_electrolyzer_case(:add_balance)
        stoich_case = make_electrolyzer_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_electrolyzer_solution(add_balance_case.asset, add_balance_model)
        assert_electrolyzer_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.h2_edge, t)) ≈ value(flow(stoich_case.asset.h2_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_electrolyzer_balance()

end # module TestAssetElectrolyzerBalance
