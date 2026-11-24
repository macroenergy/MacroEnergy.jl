module TestAssetLocation

using Test
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    AbstractEdge,
    BECCSHydrogen,
    Biomass,
    CO2,
    CO2Captured,
    ConstrainedFossilLiquidFuels,
    Electricity,
    Electrolyzer,
    Hydrogen,
    LiquidFuels,
    NaturalGas,
    ThermalPower,
    capped_edge_location,
    location,
    make

# Each asset is built with `location` at the asset level and unlocated nodes, so its edges can only get
# a location through the asset (their own `location`, or the transformation's).
function thermalpower(data)
    system = make_test_system([Electricity, NaturalGas, CO2])
    push_locations!(system, make_supply_node(NaturalGas, :fuel_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0]),
        make_demand_node(Electricity, :elec_sink, system.time_data[:Electricity], [10.0, 20.0, 30.0]),
        make_free_node(CO2, :co2_sink, system.time_data[:CO2]))
    asset = make(ThermalPower, merge(Dict{Symbol,Any}(:id => :thermal_power_test, :timedata => "Electricity",
        :fuel_commodity => "NaturalGas", :co2_sink => :co2_sink, :existing_capacity => 100.0, :fuel_consumption => 2.0,
        :emission_rate => 0.1, :fuel_start_vertex => :fuel_source, :elec_end_vertex => :elec_sink), data), system)
    return asset, asset.thermal_transform
end

function electrolyzer(data)
    system = make_test_system([Electricity, Hydrogen])
    push_locations!(system, make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0]),
        make_demand_node(Hydrogen, :h2_sink, system.time_data[:Hydrogen], [2.0, 4.0, 6.0]))
    asset = make(Electrolyzer, merge(Dict{Symbol,Any}(:id => :electrolyzer_test, :existing_capacity => 20.0,
        :efficiency_rate => 0.5, :elec_start_vertex => :elec_source, :h2_end_vertex => :h2_sink), data), system)
    return asset, asset.electrolyzer_transform
end

function beccshydrogen(data)
    system = make_test_system([Biomass, Electricity, CO2, CO2Captured, Hydrogen])
    push_locations!(system, make_supply_node(Biomass, :biomass_source, system.time_data[:Biomass], [4.0, 4.0, 4.0]),
        make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0]),
        make_supply_node(CO2, :co2_source, system.time_data[:CO2], [1.0, 1.0, 1.0]),
        make_demand_node(Hydrogen, :h2_sink, system.time_data[:Hydrogen], [1.0, 2.0, 3.0]),
        make_free_node(CO2, :co2_emission_sink, system.time_data[:CO2]),
        make_free_node(CO2Captured, :co2_captured_sink, system.time_data[:CO2Captured]))
    asset = make(BECCSHydrogen, merge(Dict{Symbol,Any}(:id => :beccs_hydrogen_test, :timedata => "Biomass",
        :existing_capacity => 100.0, :hydrogen_production => 0.5, :electricity_consumption => 0.2, :co2_content => 0.1,
        :emission_rate => 0.15, :capture_rate => 0.25, :biomass_start_vertex => :biomass_source,
        :elec_start_vertex => :elec_source, :co2_start_vertex => :co2_source, :h2_end_vertex => :h2_sink,
        :co2_emission_end_vertex => :co2_emission_sink, :co2_captured_end_vertex => :co2_captured_sink), data), system)
    return asset, asset.beccs_transform
end

function constrainedfossilliquidfuels(data)
    system = make_test_system([LiquidFuels, CO2])
    td = system.time_data[:LiquidFuels]
    push_locations!(system, make_supply_node(LiquidFuels, :fossil_gasoline_source, td, [1.0, 1.0, 1.0]),
        make_supply_node(LiquidFuels, :fossil_jetfuel_source, td, [2.0, 2.0, 2.0]),
        make_supply_node(LiquidFuels, :fossil_diesel_source, td, [3.0, 3.0, 3.0]),
        make_demand_node(LiquidFuels, :gasoline_sink, td, [10.0, 10.0, 10.0]), make_free_node(LiquidFuels, :jetfuel_sink, td),
        make_free_node(LiquidFuels, :diesel_sink, td), make_free_node(CO2, :co2_sink, system.time_data[:CO2]))
    fuels = Dict{Symbol,Any}(Symbol(p, "_commodity") => "LiquidFuels" for p in
        ("fossil_gasoline", "fossil_jetfuel", "fossil_diesel", "gasoline", "jetfuel", "diesel"))
    asset = make(ConstrainedFossilLiquidFuels, merge(fuels, Dict{Symbol,Any}(:id => :cflf_test, :timedata => "LiquidFuels",
        :jetfuel_ratio => 0.5, :diesel_ratio => 0.2, :gasoline_emission_rate => 0.1, :jetfuel_emission_rate => 0.2,
        :diesel_emission_rate => 0.3, :fossil_gasoline_start_vertex => :fossil_gasoline_source,
        :fossil_jetfuel_start_vertex => :fossil_jetfuel_source, :fossil_diesel_start_vertex => :fossil_diesel_source,
        :gasoline_end_vertex => :gasoline_sink, :jetfuel_end_vertex => :jetfuel_sink, :diesel_end_vertex => :diesel_sink,
        :co2_sink => :co2_sink), data), system)
    return asset, asset.refinery_transform
end

edges(asset) = [getfield(asset, f) for f in fieldnames(typeof(asset)) if getfield(asset, f) isa AbstractEdge]

function test_asset_location()
    @testset "asset location reaches every edge" begin
        for build in (thermalpower, electrolyzer, beccshydrogen, constrainedfossilliquidfuels)
            @testset "$build" begin
                asset, transform = build(Dict{Symbol,Any}(:location => :A))
                @test location(transform) == :A
                @test all(e -> isequal(capped_edge_location(e), :A), edges(asset))

                asset, transform = build(Dict{Symbol,Any}())
                @test ismissing(location(transform))
            end
        end
    end
    return nothing
end

test_asset_location()

end # module
