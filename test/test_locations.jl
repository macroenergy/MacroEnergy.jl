module TestLocations

using Test
import MacroEnergy as ME

function make_system(; auto_create_nodes = true)
    system = ME.empty_system(@__DIR__)
    system.settings = merge(ME.default_settings(), (; AutoCreateNodes = auto_create_nodes))
    for commodity in (ME.Electricity, ME.Hydrogen)
        system.time_data[ME.typesymbol(commodity)] = ME.TimeData{commodity}(;
            time_interval = 1:1,
            hours_per_timestep = 1,
            period_index = 1,
            subperiods = [1:1],
            subperiod_indices = [1],
            subperiod_weights = Dict(1 => 1.0),
            subperiod_map = Dict(1 => 1),
        )
    end
    location = ME.Location(; id = :Boston, system = system)
    push!(system.locations, location)
    return system, location
end

@testset "Location node membership" begin
    @testset "Automatic nodes retain membership and are reused" begin
        system, location = make_system()
        electricity = ME.find_node(system, :Boston, ME.Electricity)
        hydrogen = ME.find_node(system, :Boston, ME.Hydrogen)

        for (commodity, node) in ((ME.Electricity, electricity), (ME.Hydrogen, hydrogen))
            @test node isa ME.Node{commodity}
            @test ME.location(node) == :Boston
            @test location.nodes[ME.typesymbol(commodity)] === node
            @test ME.typesymbol(commodity) in location.commodities
            @test count(entry -> entry === node, system.locations) == 1
            for _ in 1:5
                @test ME.find_node(system, :Boston, commodity) === node
            end
            @test ME.get_zone_name(node) == "Boston"
        end
        @test length(ME.get_nodes(system)) == 2
        @test length(location.nodes) == 2

        # Location-scoped capacity constraints fall back to endpoint membership.
        edge = ME.UnidirectionalEdge{ME.Electricity}(;
            id = :electricity_edge,
            timedata = electricity.timedata,
            start_vertex = electricity,
            end_vertex = electricity,
        )
        @test ME.capped_edge_location(edge) == :Boston
    end

    @testset "Adding a node synchronizes its location field" begin
        system, location = make_system()
        node = ME.Node{ME.Electricity}(;
            id = :electricity,
            timedata = system.time_data[:Electricity],
        )
        ME.add_node!(location, node)
        @test ME.location(node) == location.id
        @test location.nodes[:Electricity] === node

        duplicate = ME.Node{ME.Electricity}(;
            id = :duplicate,
            timedata = node.timedata,
        )
        @test_throws ErrorException ME.add_node!(location, duplicate)
        @test ismissing(ME.location(duplicate))
        @test location.nodes[:Electricity] === node
    end

    @testset "Disabled automatic creation leaves membership empty" begin
        system, location = make_system(; auto_create_nodes = false)
        @test_logs (:warn, r"AutoCreateNodes = false") @test_throws ErrorException ME.find_node(system, :Boston, ME.Electricity)
        @test isempty(location.nodes)
        @test isempty(location.commodities)
        @test isempty(ME.get_nodes(system))
    end

    @testset "Unknown endpoints fail without creating nodes" begin
        for auto_create_nodes in (false, true)
            system, location = make_system(; auto_create_nodes)
            for _ in 1:2
                @test_throws r"Could not resolve endpoint `Bostno` for commodity `Electricity`.*existing node or location" ME.find_node(system, :Bostno, ME.Electricity)
                @test_throws r"Could not resolve endpoint `Bostno` to a node" ME.find_node(system, :Bostno)
                @test system.locations == [location]
                @test isempty(location.nodes)
                @test isempty(location.commodities)
                @test isempty(ME.get_nodes(system))
            end
        end
    end
end

end # module
