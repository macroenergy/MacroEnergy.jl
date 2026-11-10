module TestAssetDiagrams

using Test
using MacroEnergy

@testset "Asset Mermaid diagrams" begin
    @testset "External endpoints resolve in the diagram system" begin
        for (asset_type, external_nodes, edges) in (
            (ThermalPower, 3, 3),
            (ThermalPower{NaturalGas}, 3, 3),
            (Battery, 2, 2),
            (TransmissionLink, 2, 1),
            (TransmissionLink{Electricity}, 2, 1),
            (VRE, 1, 1),
            (ThermalHydrogenCCS, 5, 5),
            (GasStorage, 4, 6),
            (HydroRes, 3, 3),
            (CO2Injection, 2, 2),
        )
            @testset "$asset_type" begin
                diagram = mermaid_diagram(asset_type)
                @test startswith(diagram, "```mermaid")
                @test endswith(diagram, "```")
                @test count("stroke-dasharray", diagram) == external_nodes
                @test count(r"[a-z]@--", diagram) == edges
                @test !occursin("nothing", diagram)
            end
        end
    end

    @testset "Transmission connects distinct external nodes" begin
        diagram = mermaid_diagram(TransmissionLink{Electricity}; orientation="LR")
        @test occursin("direction LR", diagram)
        connection = match(r"([A-Z]) a@--transmission_edge--> ([A-Z])", diagram)
        @test !isnothing(connection)
        if !isnothing(connection)
            @test connection[1] != connection[2]
        end
    end

    @testset "File overload writes the diagram" begin
        mktempdir() do directory
            path = joinpath(directory, "battery.md")
            mermaid_diagram(Battery, path; orientation="LR")
            @test isfile(path)
            @test read(path, String) == mermaid_diagram(Battery; orientation="LR")
        end
    end
end

end # module TestAssetDiagrams
