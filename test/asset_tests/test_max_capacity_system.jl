module TestMaxCapacitySystem

using Test
using JuMP
using HiGHS
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    Electricity,
    VRE,
    Location,
    MaxCapacityConstraint,
    make,
    capacity,
    get_type,
    get_component_by_fieldname,
    capped_edge_location

# Build a VRE asset of a given technology tag, placed in a given location.
function make_vre_asset(id, technology, location, system)
    return make(
        VRE,
        Dict{Symbol,Any}(
            :id => id,
            :technology => technology,
            :location => location,
            :can_expand => true,
            :can_retire => false,
            :existing_capacity => 0.0,
            :investment_cost => 1.0,
            :availability => [1.0, 1.0, 1.0],
            :end_vertex => :sink,
        ),
        system,
    )
end

# A two-asset system: one VRE in location :A, one in location :B, both feeding a shared demand node.
function build_system()
    system = make_test_system([Electricity])
    sink = make_demand_node(Electricity, :sink, system.time_data[:Electricity], [2.0, 4.0, 1.0])
    push_locations!(system, sink)
    push!(system.assets, make_vre_asset(:solarA, "Solar", :A, system))
    push!(system.assets, make_vre_asset(:windB, "Wind", :B, system))
    return system
end

vre_cfg(value) = Dict{Symbol,Any}(:VRE => Dict{Symbol,Any}(:edge => "edge", :value => value))
nterms(cref) = length(JuMP.constraint_object(cref).func.terms)

function test_max_capacity()
    @testset "MaxCapacityConstraint" begin
        @testset "asset location resolution" begin
            system = build_system()
            solarA, windB = system.assets
            @test capped_edge_location(get_component_by_fieldname(solarA, :edge)) == :A
            @test capped_edge_location(get_component_by_fieldname(windB, :edge)) == :B
        end

        @testset "system-wide scope" begin
            system = build_system()
            ct = MaxCapacityConstraint(; config = vre_cfg(5.0))
            push!(system.constraints, ct)

            build_test_model(system)

            @test ct.constraint_ref isa Dict{Symbol,Any}
            # :VRE groups every VRE{...} in the system -> both assets contribute.
            @test nterms(ct.constraint_ref[:VRE]) == 2
        end

        @testset "per-location scope" begin
            system = build_system()
            ctA = MaxCapacityConstraint(; config = vre_cfg(3.0))
            ctB = MaxCapacityConstraint(; config = vre_cfg(5.0))
            # Location :C has a VRE cap configured but no VRE assets located there.
            ctC = MaxCapacityConstraint(; config = vre_cfg(7.0))
            push!(system.locations, Location(; id = :A, system = system, constraints = [ctA]))
            push!(system.locations, Location(; id = :B, system = system, constraints = [ctB]))
            push!(system.locations, Location(; id = :C, system = system, constraints = [ctC]))

            build_test_model(system)

            # Each location constraint sums only the assets located there.
            @test nterms(ctA.constraint_ref[:VRE]) == 1
            @test nterms(ctB.constraint_ref[:VRE]) == 1
            # Empty location group (:C) builds no constraint for that asset type.
            @test !haskey(ctC.constraint_ref, :VRE)
        end

        @testset "parameter scaling of RHS" begin
            system = build_system()
            ctsys = MaxCapacityConstraint(; config = vre_cfg(1000.0))
            ctloc = MaxCapacityConstraint(; config = vre_cfg(300.0))
            push!(system.constraints, ctsys)
            push!(system.locations, Location(; id = :A, system = system, constraints = [ctloc]))

            S = 1000.0
            MacroEnergy.scale!(system, S)
            # Cap values are scaled by 1/S, like other capacity inputs.
            @test ctsys.config[:VRE][:value] == 1.0
            @test ctloc.config[:VRE][:value] == 0.3

            MacroEnergy.unscale!(system, S)
            @test ctsys.config[:VRE][:value] == 1000.0
            @test ctloc.config[:VRE][:value] == 300.0
        end
    end
    return nothing
end

test_max_capacity()

end # module
