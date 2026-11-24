module TestAssetSubcommodityEdges

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    BalanceData,
    CO2,
    CO2Captured,
    CO2Injection,
    CO2StorageConstraint,
    Ammonia,
    ElectricHeating,
    Electricity,
    Electrolyzer,
    Heat,
    HydroRes,
    Hydrogen,
    Methanol,
    NaturalGas,
    Nitrogen,
    Node,
    SyntheticAmmonia,
    SyntheticMethanol,
    ThermalHeating,
    VRE,
    commodity_type,
    commodity_types,
    flow,
    load_commodities,
    make

# Sub-commodities declared with `acts_like`; test-only names avoid clashing with other suites.
load_commodities(
    Any[
        Dict{Symbol,Any}(:name => "SubTestElectricityLowVoltage", :acts_like => "Electricity"),
        Dict{Symbol,Any}(:name => "SubTestElectricityHydro", :acts_like => "Electricity"),
        Dict{Symbol,Any}(:name => "SubTestHeatRural", :acts_like => "Heat"),
        Dict{Symbol,Any}(:name => "SubTestCO2CapturedSequestration", :acts_like => "CO2Captured"),
        Dict{Symbol,Any}(:name => "SubTestHydrogenGreen", :acts_like => "Hydrogen"),
    ],
    "";
    write_subcommodities = false,
)

child_or(parent::DataType, child::Symbol, use_child::Bool) = use_child ? commodity_types()[child] : parent

function system_with(types::Vector{DataType})
    return make_test_system(unique(types))
end

function make_vre_case(use_child::Bool)
    elec = child_or(Electricity, :SubTestElectricityLowVoltage, use_child)
    system = system_with([Electricity, elec])
    sink = make_demand_node(elec, :vre_sink, system.time_data[Symbol(nameof(elec))], [2.0, 4.0, 1.0])
    push_locations!(system, sink)
    asset = make(VRE, Dict{Symbol,Any}(
        :id => :vre_test, :can_expand => false, :can_retire => false, :existing_capacity => 4.0,
        :availability => [0.5, 1.0, 0.25], :end_vertex => :vre_sink, :elec_commodity => string(nameof(elec)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.edge], typed = [(asset.edge, elec)])
end

function make_electricheating_case(use_child::Bool)
    elec = child_or(Electricity, :SubTestElectricityLowVoltage, use_child)
    heat = child_or(Heat, :SubTestHeatRural, use_child)
    system = system_with([Electricity, Heat, elec, heat])
    source = make_supply_node(elec, :elec_source, system.time_data[Symbol(nameof(elec))], [1.0, 1.0, 1.0])
    sink = make_demand_node(heat, :heat_sink, system.time_data[Symbol(nameof(heat))], [2.0, 4.0, 6.0])
    push_locations!(system, source, sink)
    asset = make(ElectricHeating, Dict{Symbol,Any}(
        :id => :electric_heating_test, :can_expand => false, :can_retire => false, :existing_capacity => 20.0,
        :elec_consumption => 0.5, :elec_start_vertex => :elec_source, :heat_end_vertex => :heat_sink,
        :elec_commodity => string(nameof(elec)), :heat_commodity => string(nameof(heat)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.heat_edge, asset.elec_edge], typed = [(asset.heat_edge, heat), (asset.elec_edge, elec)])
end

function make_thermalheating_case(use_child::Bool)
    heat = child_or(Heat, :SubTestHeatRural, use_child)
    system = system_with([Heat, NaturalGas, CO2, heat])
    fuel = make_supply_node(NaturalGas, :fuel_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0])
    sink = make_demand_node(heat, :heat_sink, system.time_data[Symbol(nameof(heat))], [10.0, 20.0, 30.0])
    co2 = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, fuel, sink, co2)
    asset = make(ThermalHeating, Dict{Symbol,Any}(
        :id => :thermal_heating_test, :timedata => "Heat", :fuel_commodity => "NaturalGas", :co2_sink => :co2_sink,
        :can_expand => false, :can_retire => false, :existing_capacity => 100.0, :fuel_consumption => 2.0,
        :emission_rate => 0.1, :fuel_start_vertex => :fuel_source, :heat_end_vertex => :heat_sink,
        :heat_commodity => string(nameof(heat)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.heat_edge, asset.fuel_edge, asset.co2_edge], typed = [(asset.heat_edge, heat)])
end

function make_hydrores_case(use_child::Bool)
    water = child_or(Electricity, :SubTestElectricityHydro, use_child)
    system = system_with([Electricity, water])
    source = make_free_node(water, :hydro_source, system.time_data[Symbol(nameof(water))])
    sink = make_demand_node(Electricity, :hydro_sink, system.time_data[:Electricity], [0.0, 3.0, 1.5])
    push_locations!(system, source, sink)
    asset = make(HydroRes, Dict{Symbol,Any}(
        :id => :hydrores_test, :storage_can_expand => false, :storage_can_retire => false,
        :discharge_can_expand => false, :discharge_can_retire => false, :inflow_can_expand => false,
        :inflow_can_retire => false, :storage_existing_capacity => 10.0, :discharge_existing_capacity => 4.0,
        :inflow_existing_capacity => 4.0, :discharge_efficiency => 0.5, :inflow_efficiency => 0.75,
        :hydro_source => :hydro_source, :discharge_end_vertex => :hydro_sink,
        :inflow_commodity => string(nameof(water)), :spill_commodity => string(nameof(water)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.discharge_edge, asset.inflow_edge, asset.spill_edge],
            typed = [(asset.inflow_edge, water), (asset.spill_edge, water), (asset.discharge_edge, Electricity)])
end

function make_co2injection_case(use_child::Bool)
    stored = child_or(CO2Captured, :SubTestCO2CapturedSequestration, use_child)
    system = system_with([CO2Captured, stored])
    source = make_supply_node(CO2Captured, :co2_source, system.time_data[:CO2Captured], [1.0, 1.0, 1.0])
    sink = make_demand_node(stored, :storage_sink, system.time_data[Symbol(nameof(stored))], [1.0, 2.0, 3.0])
    push_locations!(system, source, sink)
    asset = make(CO2Injection, Dict{Symbol,Any}(
        :id => :co2_injection_test, :can_expand => false, :can_retire => false, :existing_capacity => 10.0,
        :co2_source => :co2_source, :co2_storage => :storage_sink, :co2_storage_commodity => string(nameof(stored)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.co2_captured_edge, asset.co2_storage_edge],
            typed = [(asset.co2_storage_edge, stored), (asset.co2_captured_edge, CO2Captured)])
end

function make_electrolyzer_case(use_child::Bool)
    h2 = child_or(Hydrogen, :SubTestHydrogenGreen, use_child)
    system = system_with([Electricity, Hydrogen, h2])
    source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    sink = make_demand_node(h2, :h2_sink, system.time_data[Symbol(nameof(h2))], [2.0, 4.0, 1.0])
    push_locations!(system, source, sink)
    asset = make(Electrolyzer, Dict{Symbol,Any}(
        :id => :electrolyzer_test, :can_expand => false, :can_retire => false, :existing_capacity => 10.0,
        :efficiency_rate => 0.5, :elec_start_vertex => :elec_source, :h2_end_vertex => :h2_sink,
        :h2_commodity => string(nameof(h2)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.h2_edge, asset.elec_edge], typed = [(asset.h2_edge, h2)])
end

function make_syntheticammonia_case(use_child::Bool)
    h2 = child_or(Hydrogen, :SubTestHydrogenGreen, use_child)
    system = system_with([Electricity, Hydrogen, Nitrogen, Ammonia, h2])
    h2_source = make_supply_node(h2, :h2_source, system.time_data[Symbol(nameof(h2))], [1.0, 1.0, 1.0])
    n2_source = make_supply_node(Nitrogen, :n2_source, system.time_data[:Nitrogen], [0.0, 0.0, 0.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [0.0, 0.0, 0.0])
    sink = make_demand_node(Ammonia, :nh3_sink, system.time_data[:Ammonia], [2.0, 4.0, 1.0])
    push_locations!(system, h2_source, n2_source, elec_source, sink)
    asset = make(SyntheticAmmonia, Dict{Symbol,Any}(
        :id => :synthetic_ammonia_test, :h2_consumption => 1.5, :n2_consumption => 0.2,
        :electricity_consumption => 0.1, :nh3_can_expand => false, :nh3_can_retire => false,
        :nh3_existing_capacity => 10.0, :h2_start_vertex => :h2_source, :n2_start_vertex => :n2_source,
        :elec_start_vertex => :elec_source, :nh3_end_vertex => :nh3_sink, :h2_commodity => string(nameof(h2)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.h2_edge, asset.n2_edge, asset.elec_edge, asset.nh3_edge],
            typed = [(asset.h2_edge, h2)])
end

function make_syntheticmethanol_case(use_child::Bool)
    h2 = child_or(Hydrogen, :SubTestHydrogenGreen, use_child)
    system = system_with([Electricity, Hydrogen, CO2Captured, CO2, Methanol, h2])
    h2_source = make_supply_node(h2, :h2_source, system.time_data[Symbol(nameof(h2))], [1.0, 1.0, 1.0])
    co2_source = make_supply_node(CO2Captured, :co2_source, system.time_data[:CO2Captured], [0.0, 0.0, 0.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [0.0, 0.0, 0.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    sink = make_demand_node(Methanol, :ch3oh_sink, system.time_data[:Methanol], [2.0, 4.0, 1.0])
    push_locations!(system, h2_source, co2_source, elec_source, co2_sink, sink)
    asset = make(SyntheticMethanol, Dict{Symbol,Any}(
        :id => :synthetic_methanol_test, :h2_consumption => 1.5, :co2_consumption => 0.2,
        :electricity_consumption => 0.1, :emission_rate => 0.0, :ch3oh_can_expand => false,
        :ch3oh_can_retire => false, :ch3oh_existing_capacity => 10.0, :h2_start_vertex => :h2_source,
        :co2_captured_start_vertex => :co2_source, :elec_start_vertex => :elec_source,
        :co2_emission_end_vertex => :co2_sink, :ch3oh_end_vertex => :ch3oh_sink, :h2_commodity => string(nameof(h2)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.h2_edge, asset.co2_captured_edge, asset.elec_edge, asset.ch3oh_edge],
            typed = [(asset.h2_edge, h2)])
end

# Injection is paid 1 per tonne and its capacity (30 over the 3 steps) is slack, so only the storage cap of 4 binds.
function make_co2storage_case(use_child::Bool)
    stored = child_or(CO2Captured, :SubTestCO2CapturedSequestration, use_child)
    system = system_with([CO2Captured, stored])
    source = make_supply_node(CO2Captured, :co2_source, system.time_data[:CO2Captured], [-1.0, -1.0, -1.0])
    sink = Node{stored}(;
        id = :storage_sink,
        timedata = system.time_data[Symbol(nameof(stored))],
        constraints = [CO2StorageConstraint()],
        balance_data = Dict(:co2_storage => BalanceData()),
        rhs_policy = Dict{DataType,Float64}(CO2StorageConstraint => 4.0),
    )
    push_locations!(system, source, sink)
    asset = make(CO2Injection, Dict{Symbol,Any}(
        :id => :co2_injection_test, :can_expand => false, :can_retire => false, :existing_capacity => 10.0,
        :co2_source => :co2_source, :co2_storage => :storage_sink, :co2_storage_commodity => string(nameof(stored)),
    ), system)
    push!(system.assets, asset)
    return (; system, asset, edges = [asset.co2_captured_edge, asset.co2_storage_edge],
            typed = [(asset.co2_storage_edge, stored), (asset.co2_captured_edge, CO2Captured)])
end

function test_parent_and_child_agree(name, builder, expected_objective)
    @testset "$name on a sub-commodity node" begin
        parent = builder(false)
        child = builder(true)
        parent_model = build_test_model(parent.system)
        child_model = build_test_model(child.system)

        @test objective_value(parent_model) ≈ expected_objective atol = 1e-8
        @test objective_value(child_model) ≈ objective_value(parent_model) atol = 1e-8
        for (edge_p, edge_c) in zip(parent.edges, child.edges)
            for t in 1:3
                @test value(flow(edge_c, t)) ≈ value(flow(edge_p, t)) atol = 1e-8
            end
        end
        for (edge, expected) in child.typed
            @test commodity_type(edge) === expected
        end
        for (edge, _) in parent.typed
            @test commodity_type(edge) in (Electricity, Heat, CO2Captured, Hydrogen)
        end
    end
end

function test_asset_subcommodity_edges()
    test_parent_and_child_agree("VRE", make_vre_case, 0.0)
    test_parent_and_child_agree("ElectricHeating", make_electricheating_case, 6.0)
    test_parent_and_child_agree("ThermalHeating", make_thermalheating_case, 240.0)
    test_parent_and_child_agree("HydroRes", make_hydrores_case, 0.0)
    test_parent_and_child_agree("CO2Injection", make_co2injection_case, 6.0)
    test_parent_and_child_agree("CO2StorageConstraint", make_co2storage_case, -4.0)
    test_parent_and_child_agree("Electrolyzer", make_electrolyzer_case, 14.0)
    test_parent_and_child_agree("SyntheticAmmonia", make_syntheticammonia_case, 10.5)
    test_parent_and_child_agree("SyntheticMethanol", make_syntheticmethanol_case, 10.5)

    @testset "a commodity outside the family, or an unknown one, is rejected" begin
        system = make_test_system([Electricity, Heat])
        sink = make_demand_node(Heat, :heat_sink, system.time_data[:Heat], [1.0, 1.0, 1.0])
        push_locations!(system, sink)
        vre_input(commodity) = Dict{Symbol,Any}(
            :id => :vre_wrong, :can_expand => false, :can_retire => false, :existing_capacity => 1.0,
            :availability => [1.0, 1.0, 1.0], :end_vertex => :heat_sink, :elec_commodity => commodity,
        )
        caught(f) = try f(); nothing catch err; err end

        err = caught(() -> make(VRE, vre_input("Heat"), system))
        @test err isa ArgumentError
        @test all(s -> occursin(s, err.msg), ("vre_wrong", "`edge`", "commodity Heat", "sub-commodity of Electricity"))

        err = caught(() -> make(VRE, vre_input("NotACommodity"), system))
        @test err isa ArgumentError
        @test all(s -> occursin(s, err.msg), ("vre_wrong", "`edge`", "NotACommodity", "not a defined commodity"))
    end
    return nothing
end

test_asset_subcommodity_edges()

end # module TestAssetSubcommodityEdges
