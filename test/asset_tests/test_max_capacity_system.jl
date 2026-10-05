module TestMaxCapacitySystem

using Test
using JuMP
using HiGHS
using MacroEnergy
using JSON3

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    Electricity,
    VRE,
    Location,
    MaxCapacityConstraint,
    MaxCapacityConstraintConfig,
    GroupConfig,
    GroupSelector,
    make,
    capacity,
    get_type,
    get_component_by_fieldname,
    capped_edge_location

# Build a VRE asset of a given technology tag, placed in a given location.
function make_vre_asset(id, technology, location, system; tags = [technology])
    return make(
        VRE,
        Dict{Symbol,Any}(
            :id => id,
            :technology => technology,
            :tags => tags,
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
    push!(system.assets, make_vre_asset(:windB, "Wind", :B, system; tags = ["Renewable", "Wind", "Utility Scale", "Retired"]))
    return system
end

vre_cfg(value) = MaxCapacityConstraintConfig([
    GroupConfig(:VRE, GroupSelector(:VRE), :edge, value),
])
nterms(cref) = length(JuMP.constraint_object(cref).func.terms)

function test_max_capacity()
    @testset "MaxCapacityConstraint" begin
        @testset "asset location resolution" begin
            system = build_system()
            solarA, windB = system.assets
            @test solarA.tags == [:solar]
            @test windB.tags == [:renewable, :retired, :utility_scale, :wind]
            @test capped_edge_location(get_component_by_fieldname(solarA, :edge)) == :A
            @test capped_edge_location(get_component_by_fieldname(windB, :edge)) == :B
        end

        @testset "tag selectors" begin
            @test MacroEnergy.asset_tags(Dict{Symbol,Any}()) === nothing
            @test MacroEnergy.asset_tags(Dict{Symbol,Any}(:tags => String[])) === nothing
            @test MacroEnergy.asset_tags(Dict{Symbol,Any}(:tags => "Utility Scale")) == [:utility_scale]
            merged = only(MacroEnergy.merge_global_data(Dict{Symbol,Any}(
                :type => "VRE",
                :global_data => Dict{Symbol,Any}(:tags => "Renewable"),
                :instance_data => [Dict{Symbol,Any}(:id => "solar", :tags => "Solar-PV")],
            )))[:instance_data]
            @test MacroEnergy.asset_tags(merged) == [:renewable, :solar_pv]

            system = build_system()
            solarA, windB = system.assets
            solarA = make_vre_asset(:solarA, "Solar", :A, system; tags = ["Renewable", "Solar", "Utility Scale"])
            system.assets[1] = solarA
            @test MacroEnergy.prepare_to_json(solarA)[:instance_data][:tags] == ["renewable", "solar", "utility_scale"]

            selector = GroupSelector(:VRE, [:renewable], [:utility_scale, :distributed], [:retired])
            ct = MaxCapacityConstraint(; config = MaxCapacityConstraintConfig([
                GroupConfig(:solar_vre, selector, :edge, 5.0),
            ]))
            push!(system.constraints, ct)

            build_test_model(system)
            @test nterms(ct.constraint_ref[:solar_vre]) == 1
            @test :retired in something(windB.tags, Symbol[])

            technology_tagged = make_vre_asset(:technology_tagged, "Solar", :A, system; tags = String[])
            @test technology_tagged.tags == [:solar]

            legacy = Dict{Symbol,Any}(:constraints => Dict{Symbol,Any}(
                :MaxCapacityConstraint => Dict{Symbol,Any}(
                    Symbol("VRE{Solar}") => Dict{Symbol,Any}(:edge => "edge", :value => 5.0),
                ),
            ))
            MacroEnergy.check_and_convert_constraints!(legacy)
            legacy_selector = only(only(legacy[:constraints]).config.groups).selector
            @test legacy_selector.asset_type == :VRE
            @test legacy_selector.all == [:solar]
            @test MacroEnergy.select_assets(system, legacy_selector) == [solarA]

            explicit = Dict{Symbol,Any}(:constraints => Dict{Symbol,Any}(
                :MaxCapacityConstraint => Dict{Symbol,Any}(
                    :active_vre => Dict{Symbol,Any}(
                        :select => Dict{Symbol,Any}(
                            :asset_type => "VRE",
                            :all => ["Renewable"],
                            :any => ["Utility Scale", "Distributed"],
                            :exclude => ["Retired"],
                        ),
                        :edge => "edge",
                        :value => 5.0,
                    ),
                ),
            ))
            MacroEnergy.check_and_convert_constraints!(explicit)
            parsed = only(only(explicit[:constraints]).config.groups)
            @test parsed.name == :active_vre
            @test parsed.selector.asset_type == selector.asset_type
            @test parsed.selector.all == selector.all
            @test parsed.selector.any == selector.any
            @test parsed.selector.exclude == selector.exclude
        end

        @testset "system-wide scope" begin
            system = build_system()
            ct = MaxCapacityConstraint(; config = vre_cfg(5.0))
            push!(system.constraints, ct)

            build_test_model(system)

            @test ct.constraint_ref isa Dict{Symbol,Any}
            # :VRE groups both VRE assets in the system.
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
            @test only(ctsys.config.groups).value == 1.0
            @test only(ctloc.config.groups).value == 0.3

            MacroEnergy.unscale!(system, S)
            @test only(ctsys.config.groups).value == 1000.0
            @test only(ctloc.config.groups).value == 300.0
        end

        @testset "JSON payload scaling" begin
            raw = JSON3.read("""
            {
              "MaxCapacityConstraint": {
                "VRE": { "edge": "edge", "value": 1000.0 }
              }
            }
            """)
            data = Dict{Symbol,Any}(:constraints => raw)
            MacroEnergy.check_and_convert_constraints!(data)
            ct = only(data[:constraints])
            @test ct.config isa MaxCapacityConstraintConfig
            @test only(ct.config.groups).value == 1000.0

            system = MacroEnergy.empty_system("json_payload_scaling")
            push!(system.constraints, ct)
            MacroEnergy.scale!(system, 1000.0)
            @test only(ct.config.groups).value == 1.0
            MacroEnergy.unscale!(system, 1000.0)
            @test only(ct.config.groups).value == 1000.0
        end

        @testset "payload validation" begin
            invalid_payloads = (
                Dict{Symbol,Any}(:VRE => Dict{Symbol,Any}(:value => 1.0)),
                Dict{Symbol,Any}(:VRE => Dict{Symbol,Any}(:edge => "edge")),
                Dict{Symbol,Any}(:VRE => true),
                Dict{Symbol,Any}(:VRE => Dict{Symbol,Any}(:edge => 1, :value => 1.0)),
                Dict{Symbol,Any}(:VRE => Dict{Symbol,Any}(:edge => "edge", :value => "one")),
                Dict{Symbol,Any}(:VRE => Dict{Symbol,Any}(:edge => "edge", :value => NaN)),
                Dict{Symbol,Any}(:VRE => Dict{Symbol,Any}(:edge => "edge", :value => 1.0, :extra => true)),
                Dict{Symbol,Any}(:solar => Dict{Symbol,Any}(:select => Dict{Symbol,Any}(:all => ["solar!"]), :edge => "edge", :value => 1.0)),
                Dict{Symbol,Any}(:solar => Dict{Symbol,Any}(:select => Dict{Symbol,Any}(:any => "solar"), :edge => "edge", :value => 1.0)),
            )
            for payload in invalid_payloads
                data = Dict{Symbol,Any}(:constraints => Dict{Symbol,Any}(
                    :MaxCapacityConstraint => payload,
                ))
                @test_throws ArgumentError MacroEnergy.check_and_convert_constraints!(data)
            end

            data = Dict{Symbol,Any}(:constraints => Dict{Symbol,Any}(
                :MaxCapacityConstraint => true,
            ))
            MacroEnergy.check_and_convert_constraints!(data)
            error = try
                MacroEnergy.validate_required_constraint_configs!(
                    data[:constraints],
                    "system scope",
                )
                nothing
            catch exception
                exception
            end
            @test error isa ArgumentError
            @test occursin("MaxCapacityConstraintConfig", sprint(showerror, error))

            location_data = Any[Dict{Symbol,Any}(
                :id => "SE",
                :constraints => Dict{Symbol,Any}(:MaxCapacityConstraint => true),
            )]
            location_system = MacroEnergy.empty_system("location_config_required")
            @test_throws ArgumentError MacroEnergy.load_locations!(
                location_system,
                "",
                location_data,
            )
        end
    end
    return nothing
end

test_max_capacity()

end # module
