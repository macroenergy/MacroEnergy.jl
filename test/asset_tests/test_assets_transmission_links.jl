module TestAssetsTransmissionLinks

using Test
using MacroEnergy

import MacroEnergy: TransmissionLink, OneWayTransmissionLink, load_system, unidirectional

const test_path = joinpath(@__DIR__, "..", "test_inputs")

function make_transmission_data(; id::String, origin::String, dest::String)
    return Dict{Symbol,Any}(
        :id => id,
        :commodity => "Electricity",
        :transmission_origin => origin,
        :transmission_dest => dest,
        :can_expand => true,
        :existing_capacity => 10.0,
        :investment_cost => 1000.0,
    )
end

function test_transmission_link_inputs()
    system = load_system(test_path)

    @testset "TransmissionLink simple input" begin
        data = make_transmission_data(id = "tx_link", origin = "elec_MA", dest = "elec_CT")
        asset = MacroEnergy.make(TransmissionLink, deepcopy(data), system)

        @test asset.id == :tx_link
        @test asset.transmission_edge.start_vertex.id == :elec_MA
        @test asset.transmission_edge.end_vertex.id == :elec_CT
        @test !unidirectional(asset.transmission_edge)
    end

    @testset "OneWayTransmissionLink simple input" begin
        data = make_transmission_data(id = "ow_link", origin = "elec_MA", dest = "elec_CT")
        asset = MacroEnergy.make(OneWayTransmissionLink, deepcopy(data), system)

        @test asset.id == :ow_link
        @test asset.transmission_edge.start_vertex.id == :elec_MA
        @test asset.transmission_edge.end_vertex.id == :elec_CT
        @test unidirectional(asset.transmission_edge)
    end

    @testset "Same-vertex warnings" begin
        bidir_data = make_transmission_data(id = "same_bidir", origin = "elec_MA", dest = "elec_MA")
        @test_logs (:warn, r"TransmissionLink same_bidir has identical start and end vertices") begin
            MacroEnergy.make(TransmissionLink, deepcopy(bidir_data), system)
        end

        oneway_data = make_transmission_data(id = "same_oneway", origin = "elec_MA", dest = "elec_MA")
        @test_logs (:warn, r"OneWayTransmissionLink same_oneway has identical start and end vertices") begin
            MacroEnergy.make(OneWayTransmissionLink, deepcopy(oneway_data), system)
        end
    end

    return nothing
end

test_transmission_link_inputs()

end # module TestAssetsTransmissionLinks
