module TestAssetHydroResBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_to_balance,
    @add_to_storage_balance,
    Electricity,
    HydroRes,
    flow,
    make,
    storage_level

function make_hydrores_case(style::Symbol)
    system = make_test_system([Electricity])

    hydro_source = make_free_node(Electricity, :hydro_source, system.time_data[:Electricity])
    discharge_sink = make_demand_node(Electricity, :hydro_sink, system.time_data[:Electricity], [0.0, 3.0, 1.5])
    push_locations!(system, hydro_source, discharge_sink)

    asset = make(
        HydroRes,
        Dict{Symbol,Any}(
            :id => :hydrores_test,
            :storage_can_expand => false,
            :storage_can_retire => false,
            :discharge_can_expand => false,
            :discharge_can_retire => false,
            :inflow_can_expand => false,
            :inflow_can_retire => false,
            :storage_existing_capacity => 10.0,
            :discharge_existing_capacity => 4.0,
            :inflow_existing_capacity => 4.0,
            :discharge_efficiency => 0.5,
            :inflow_efficiency => 0.75,
            :hydro_source => :hydro_source,
            :discharge_end_vertex => :hydro_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    if style == :manual_storage
        asset.hydrostor.balance_data = Dict{Symbol,Any}()
        @add_to_storage_balance(
            asset.hydrostor,
            2.0 * flow(asset.discharge_edge) + 0.75 * flow(asset.inflow_edge) + flow(asset.spill_edge),
        )
    elseif style != :default
        error("Unsupported HydroRes balance style: $style")
    end

    return (; system, asset)
end

function assert_hydrores_solution(asset, model)
    expected_inflow = [4.0, 4.0, 4.0]
    expected_discharge = [0.0, 3.0, 1.5]
    expected_spill = [0.0, 0.0, 0.0]
    expected_storage = [3.0, 0.0, 0.0]

    @test objective_value(model) ≈ 0.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.inflow_edge, t)) ≈ expected_inflow[t] atol = 1e-8
        @test value(flow(asset.discharge_edge, t)) ≈ expected_discharge[t] atol = 1e-8
        @test value(flow(asset.spill_edge, t)) ≈ expected_spill[t] atol = 1e-8
        @test value(storage_level(asset.hydrostor, t)) ≈ expected_storage[t] atol = 1e-8
    end
end

function test_asset_hydrores_balance()
    @testset "HydroRes Small Solve Cases" begin
        default_case = make_hydrores_case(:default)
        manual_case = make_hydrores_case(:manual_storage)

        default_model = build_test_model(default_case.system)
        manual_model = build_test_model(manual_case.system)

        assert_hydrores_solution(default_case.asset, default_model)
        assert_hydrores_solution(manual_case.asset, manual_model)

        for t in 1:3
            @test value(flow(default_case.asset.inflow_edge, t)) ≈ value(flow(manual_case.asset.inflow_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.discharge_edge, t)) ≈ value(flow(manual_case.asset.discharge_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.spill_edge, t)) ≈ value(flow(manual_case.asset.spill_edge, t)) atol = 1e-8
            @test value(storage_level(default_case.asset.hydrostor, t)) ≈ value(storage_level(manual_case.asset.hydrostor, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(manual_model) atol = 1e-8
    end

    return nothing
end

test_asset_hydrores_balance()

end # module TestAssetHydroResBalance
