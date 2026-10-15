module TestAssetCO2EdgeConstraints

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    BlastFurnaceBasicOxygenFurnace,
    BlastFurnaceBasicOxygenFurnaceCCS,
    CapacityConstraint,
    CO2,
    CO2Captured,
    Coal,
    CrudeSteel,
    ElectricArcFurnace,
    Electricity,
    IronOre,
    MinFlowConstraint,
    NaturalGas,
    SteelScrap,
    flow,
    make

function make_co2_constraint_case(asset_type, constraints)
    commodities = [IronOre, SteelScrap, Coal, NaturalGas, CrudeSteel, Electricity, CO2, CO2Captured]
    system = make_test_system(commodities)
    for commodity in commodities
        id = Symbol(nameof(commodity))
        push!(system.locations, make_free_node(commodity, id, system.time_data[id]))
    end

    co2_data = Dict{Symbol,Any}(
        :has_capacity => true,
        :can_expand => false,
        :can_retire => false,
        :existing_capacity => 1.0,
        :min_flow_fraction => 0.25,
    )
    if constraints !== nothing
        co2_data[:constraints] = constraints
    end
    data = Dict{Symbol,Any}(
        :id => :steel_test,
        :transforms => Dict{Symbol,Any}(
            :timedata => "CrudeSteel",
            :emission_rate => 0.5,
        ),
        :edges => Dict{Symbol,Any}(
            :co2_edge => co2_data,
            :carbonsource_edge => Dict{Symbol,Any}(:commodity => "Coal"),
            :crudesteel_edge => Dict{Symbol,Any}(
                :can_expand => false,
                :can_retire => false,
                :existing_capacity => 10.0,
            ),
        ),
        :ironore_start_vertex => :IronOre,
        :steelscrap_start_vertex => :SteelScrap,
        :metcoal_start_vertex => :Coal,
        :thermalcoal_start_vertex => :Coal,
        :natgas_start_vertex => :NaturalGas,
        :naturalgas_start_vertex => :NaturalGas,
        :carbonsource_start_vertex => :Coal,
        :elec_start_vertex => :Electricity,
        :elec_end_vertex => :Electricity,
        :crudesteel_end_vertex => :CrudeSteel,
        :co2_sink => :CO2,
        :co2_captured_end_vertex => :CO2Captured,
    )
    asset = make(asset_type, data, system)
    push!(system.assets, asset)
    return (; system, asset)
end

@testset "Steel asset CO2 edge constraints" begin
    for asset_type in (BlastFurnaceBasicOxygenFurnace, BlastFurnaceBasicOxygenFurnaceCCS, ElectricArcFurnace)
        @testset "$asset_type" begin
            for (name, input, expected_types, expected_steel) in (
                ("omitted", nothing, [], 10.0),
                ("empty", Dict{Symbol,Bool}(), [], 10.0),
                ("disabled", Dict(:CapacityConstraint => false), [], 10.0),
                ("enabled", Dict(:CapacityConstraint => true, :MinFlowConstraint => false), [CapacityConstraint], 2.0),
                ("multiple", Dict(:CapacityConstraint => true, :MinFlowConstraint => true), [CapacityConstraint, MinFlowConstraint], 2.0),
            )
                @testset "$name" begin
                    case = make_co2_constraint_case(asset_type, input)
                    @test Set(typeof.(case.asset.co2_edge.constraints)) == Set(expected_types)

                    model = build_test_model(case.system)
                    @objective(model, Max, sum(flow(case.asset.crudesteel_edge)))
                    optimize!(model)

                    @test termination_status(model) == MOI.OPTIMAL
                    @test value.(flow(case.asset.crudesteel_edge)) ≈ fill(expected_steel, 3) atol = 1e-8
                    @test value.(flow(case.asset.co2_edge)) ≈ fill(0.5 * expected_steel, 3) atol = 1e-8
                end
            end
        end
    end
end

end # module TestAssetCO2EdgeConstraints
