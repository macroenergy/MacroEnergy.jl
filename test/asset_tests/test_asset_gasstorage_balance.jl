module TestAssetGasStorageBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_to_balance,
    @add_to_storage_balance,
    Electricity,
    GasStorage,
    NaturalGas,
    flow,
    make,
    storage_level

function make_gasstorage_case(style::Symbol)
    system = make_test_system([Electricity, NaturalGas])

    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 10.0, 2.0])
    gas_source = make_supply_node(NaturalGas, :gas_source, system.time_data[:NaturalGas], [1.0, 10.0, 2.0])
    gas_sink = make_demand_node(NaturalGas, :gas_sink, system.time_data[:NaturalGas], [0.0, 4.0, 0.0])
    push_locations!(system, elec_source, gas_source, gas_sink)

    asset = make(
        GasStorage,
        Dict{Symbol,Any}(
            :id => :gas_storage_test,
            :storage_commodity => "NaturalGas",
            :storage_can_expand => false,
            :storage_can_retire => false,
            :charge_can_expand => false,
            :charge_can_retire => false,
            :discharge_can_expand => false,
            :discharge_can_retire => false,
            :storage_existing_capacity => 10.0,
            :charge_existing_capacity => 10.0,
            :discharge_existing_capacity => 10.0,
            :charge_efficiency => 0.8,
            :discharge_efficiency => 0.5,
            :charge_electricity_consumption => 0.1,
            :discharge_electricity_consumption => 0.2,
            :charge_elec_start_vertex => :elec_source,
            :discharge_elec_start_vertex => :elec_source,
            :external_charge_start_vertex => :gas_source,
            :external_discharge_end_vertex => :gas_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    if style == :add_balance
        asset.gas_storage.balance_data = Dict{Symbol,Any}()
        asset.pump_transform.balance_data = Dict{Symbol,Any}()

        @add_to_storage_balance(
            asset.gas_storage,
            2.0 * flow(asset.discharge_edge) + 0.8 * flow(asset.charge_edge),
        )
        @add_balance(asset.pump_transform, :charging_gas, flow(asset.external_charge_edge) == flow(asset.charge_edge))
        @add_balance(asset.pump_transform, :charging_electricity, 0.1 * flow(asset.external_charge_edge) == flow(asset.charge_elec_edge))
        @add_balance(asset.pump_transform, :discharging_gas, flow(asset.discharge_edge) == flow(asset.external_discharge_edge))
        @add_balance(asset.pump_transform, :discharging_electricity, 0.2 * flow(asset.external_discharge_edge) == flow(asset.discharge_elec_edge))
    elseif style != :default
        error("Unsupported GasStorage balance style: $style")
    end

    return (; system, asset)
end

function assert_gasstorage_solution(asset, model)
    expected_storage = [8.0, 0.0, 0.0]
    expected_charge = [10.0, 0.0, 0.0]
    expected_discharge = [0.0, 4.0, 0.0]
    expected_external_charge = [10.0, 0.0, 0.0]
    expected_external_discharge = [0.0, 4.0, 0.0]
    expected_charge_elec = [1.0, 0.0, 0.0]
    expected_discharge_elec = [0.0, 0.8, 0.0]

    @test objective_value(model) ≈ 19.0 atol = 1e-8
    for t in 1:3
        @test value(storage_level(asset.gas_storage, t)) ≈ expected_storage[t] atol = 1e-8
        @test value(flow(asset.charge_edge, t)) ≈ expected_charge[t] atol = 1e-8
        @test value(flow(asset.discharge_edge, t)) ≈ expected_discharge[t] atol = 1e-8
        @test value(flow(asset.external_charge_edge, t)) ≈ expected_external_charge[t] atol = 1e-8
        @test value(flow(asset.external_discharge_edge, t)) ≈ expected_external_discharge[t] atol = 1e-8
        @test value(flow(asset.charge_elec_edge, t)) ≈ expected_charge_elec[t] atol = 1e-8
        @test value(flow(asset.discharge_elec_edge, t)) ≈ expected_discharge_elec[t] atol = 1e-8
    end
end

function test_asset_gasstorage_balance()
    @testset "GasStorage Small Solve Cases" begin
        default_case = make_gasstorage_case(:default)
        add_balance_case = make_gasstorage_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_gasstorage_solution(default_case.asset, default_model)
        assert_gasstorage_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(storage_level(default_case.asset.gas_storage, t)) ≈ value(storage_level(add_balance_case.asset.gas_storage, t)) atol = 1e-8
            @test value(flow(default_case.asset.charge_edge, t)) ≈ value(flow(add_balance_case.asset.charge_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.discharge_edge, t)) ≈ value(flow(add_balance_case.asset.discharge_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.external_charge_edge, t)) ≈ value(flow(add_balance_case.asset.external_charge_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.external_discharge_edge, t)) ≈ value(flow(add_balance_case.asset.external_discharge_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.charge_elec_edge, t)) ≈ value(flow(add_balance_case.asset.charge_elec_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.discharge_elec_edge, t)) ≈ value(flow(add_balance_case.asset.discharge_elec_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_gasstorage_balance()

end # module TestAssetGasStorageBalance
