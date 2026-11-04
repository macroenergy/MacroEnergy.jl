module TestLocations

using Test
using JSON3
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
                @test_throws r"Could not find `Bostno` for commodity `Electricity`.*existing node or location" ME.find_node(system, :Bostno, ME.Electricity)
                @test_throws r"Could not find `Bostno` in the list of nodes or locations" ME.find_node(system, :Bostno)
                @test system.locations == [location]
                @test isempty(location.nodes)
                @test isempty(location.commodities)
                @test isempty(ME.get_nodes(system))
            end
        end
    end
end

@testset "Location input validation" begin
    @testset "Typed construction boundary" begin
        input = @inferred ME.parse_location_input("SE")
        @test input isa ME.LocationInput
        @test input.id == "SE"
        @test isempty(input.constraints)
        @test ME.LocationInput(; id="SE").constraints !== ME.LocationInput(; id="MIDAT").constraints
        @test_throws ArgumentError ME.LocationInput(; id=" \t")
        @test_throws ArgumentError ME.LocationInput(; id="SE", constraints=[ME.MaxCapacityConstraint()])

        converted = @inferred ME.LocationInput(SubString(" SE ", 2, 3), Dict("MaxCapacityConstraint" => false))
        @test converted.id === "SE"
        @test converted.constraints isa Dict{Symbol,Any}
        @test converted.constraints == Dict(:MaxCapacityConstraint => false)
        for invalid_id in (1, :SE, nothing)
            @test_throws r"Location `id` must be a string" ME.LocationInput(invalid_id, Dict())
            @test_throws r"Location `id` must be a string" ME.LocationInput(; id=invalid_id)
        end
        for invalid_constraints in (nothing, ME.AbstractTypeConstraint[], Any[1])
            @test_throws r"Location `constraints` must be a dictionary" ME.LocationInput("SE", invalid_constraints)
            @test_throws r"Location `constraints` must be a dictionary" ME.LocationInput(; id="SE", constraints=invalid_constraints)
        end
        @test_throws r"constraint names must be strings or symbols" ME.LocationInput("SE", Dict(1 => false))

        # Extension fields stay in raw input until a builder deliberately consumes them.
        raw = Dict{Symbol,Any}(:id => "SE", :custom_field => Dict(:value => 42))
        original = deepcopy(raw)
        input = ME.parse_location_input(raw)
        @test input.id == "SE"
        @test raw == original
        @test !hasproperty(input, :custom_field)
        system = ME.empty_system(@__DIR__)
        location = ME.Location(input, system)
        @test location.id == :SE
        @test location.system === system
        @test isempty(location.constraints)
    end

    @testset "Strings and objects use the same schema" begin
        for entries in (["SE", "MIDAT"],
                        Any[Dict(:id => "SE"), "MIDAT"],
                        [Dict("id" => "SE"), Dict("id" => "MIDAT")],
                        JSON3.read("""[{"id":"SE"},"MIDAT"]"""))
            system = ME.empty_system(@__DIR__)
            ME.load_locations!(system, @__DIR__, entries)
            @test ME.location_ids(system) == [:SE, :MIDAT]
            @test all(location -> location.system === system, system.locations)
            @test all(location -> isempty(location.constraints), system.locations)
        end
        system = ME.empty_system(@__DIR__)
        ME.load_locations!(system, @__DIR__, "SE")
        @test ME.location_ids(system) == [:SE]
        ME.load_locations!(system, @__DIR__, String[])
        @test isempty(system.locations)
    end

    @testset "Existing constraint payloads are preserved" begin
        for constraint_name in (:MaxCapacityConstraint, :MinCapacityConstraint, :MaxNewCapacityConstraint)
            entry = Dict{Symbol,Any}(
                :id => "SE",
                :constraints => Dict(constraint_name => Dict(:VRE => Dict(:edge => "edge", :value => 300.0))),
            )
            original = deepcopy(entry)
            system = ME.empty_system(@__DIR__)
            input = ME.parse_location_input(entry)
            @test input isa ME.LocationInput
            @test input.constraints == entry[:constraints]
            @test input.constraints[constraint_name] isa AbstractDict
            runtime = ME.Location(input, system)
            @test nameof(typeof(only(runtime.constraints))) == constraint_name
            @test input.constraints == entry[:constraints]
            second_runtime = ME.Location(input, system)
            @test only(runtime.constraints) !== only(second_runtime.constraints)
            ME.load_locations!(system, @__DIR__, [entry])
            constraint = only(only(system.locations).constraints)
            @test nameof(typeof(constraint)) == constraint_name
            @test only(constraint.config.groups).value == 300.0
            @test entry == original
            ME.load_locations!(system, @__DIR__, [entry])
            @test length(only(system.locations).constraints) == 1
        end
        system = ME.empty_system(@__DIR__)
        ME.load_locations!(system, @__DIR__, [Dict(:id => "SE", :constraints => Dict())])
        @test isempty(only(system.locations).constraints)
    end

    @testset "Location files accept mixed entries" begin
        mktempdir() do directory
            write(joinpath(directory, "locations.json"), """
                {"locations": ["MIDAT", {"id": "SE", "constraints": {
                    "MaxCapacityConstraint": {"VRE": {"edge": "edge", "value": 300.0}}
                }}]}
                """)
            system = ME.empty_system(directory)
            ME.load_locations!(system, directory, Dict{Symbol,Any}(:path => "locations.json"))
            @test ME.location_ids(system) == [:MIDAT, :SE]
            @test isempty(first(system.locations).constraints)
            constraint = only(last(system.locations).constraints)
            @test constraint isa ME.MaxCapacityConstraint
            @test only(constraint.config.groups).value == 300.0
        end
    end

    @testset "Invalid entries fail before replacing system locations" begin
        invalid_entries = (
            (Dict(), r"requires an `id` field"),
            (Dict(:id => 1), r"`id` must be a string"),
            (Dict(:id => :SE), r"`id` must be a string"),
            (Dict(:id => nothing), r"`id` must be a string"),
            (Dict(:id => ""), r"`id` must be a nonempty string"),
            (" \t", r"`id` must be a nonempty string"),
            (42, r"must be an object"),
            (nothing, r"must be an object"),
            (Dict(1 => "SE"), r"must use string or symbol keys"),
            (Dict(:id => "SE", :constraints => nothing), r"`constraints` must be a dictionary"),
            (Dict(:id => "SE", :constraints => []), r"`constraints` must be a dictionary"),
            (Dict(:id => "SE", :constraints => true), r"`constraints` must be a dictionary"),
            (Dict(:id => "SE", :constraints => Dict(:MaxCapacityConstraint => true)), r"requires a .*configuration object"),
        )
        for (entry, message) in invalid_entries
            system, location = make_system()
            @test_throws message ME.load_locations!(system, @__DIR__, Any["valid", entry])
            @test system.locations == [location]
        end
    end
end

end # module
