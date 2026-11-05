module TestLocations

using Test
using JSON3
import MacroEnergy as ME

abstract type LocationTestHydrogen <: ME.Hydrogen end

function make_system(; auto_create_nodes = true)
    system = ME.empty_system(@__DIR__)
    system.settings = merge(ME.default_settings(), (; AutoCreateNodes = auto_create_nodes))
    for commodity in (ME.Electricity, ME.Hydrogen)
        system.commodities[ME.typesymbol(commodity)] = commodity
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
    ME.add!(system, location)
    return system, location
end

@testset "Location node membership" begin
    @testset "Automatic nodes retain membership and are reused" begin
        system, location = make_system()
        electricity = ME.find_node(system, :Boston, ME.Electricity)
        hydrogen = ME.find_node(system, :Boston, ME.Hydrogen)
        @test electricity.id == :Boston_Electricity
        @test hydrogen.id == :Boston_Hydrogen

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

    @testset "Rejected automatic node IDs leave location membership unchanged" begin
        for collision in (:node, :location)
            system, location = make_system()
            existing = if collision === :node
                ME.Node{ME.Electricity}(;
                    id = :Boston_Electricity,
                    timedata = system.time_data[:Electricity],
                )
            else
                ME.Location(; id = :Boston_Electricity, system = system)
            end
            ME.add!(system, existing)
            registered = copy(system.locations)

            for _ in 1:2
                @test_throws r"Duplicate network ID `Boston_Electricity`" ME.find_node(system, :Boston, ME.Electricity)
                @test isempty(location.nodes)
                @test isempty(location.commodities)
                @test system.locations == registered
            end
        end
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

    @testset "Node IDs are checked at system registration without locations" begin
        system, _ = make_system()
        empty!(system.locations)
        first_node = ME.make(ME.Electricity, Dict{Symbol,Any}(:id=>"same_id"), system)
        ME.add!(system, first_node)
        duplicate = ME.make(ME.Hydrogen, Dict{Symbol,Any}(:id=>"same_id"), system)
        @test_throws r"Duplicate network ID `same_id`" ME.add!(system, duplicate)
        @test ME.get_nodes(system) == [first_node]
        @test ismissing(duplicate.location)
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

        converted = @inferred ME.LocationInput(SubString(" SE ", 2, 3), Dict(:MaxCapacityConstraint => false))
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
        @test_throws r"Location constraints must use symbol keys" ME.LocationInput("SE", Dict(1 => false))

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

    @testset "Invalid entries stop loading at the failing entry" begin
        invalid_entries = (
            (Dict(), r"requires an `id` field"),
            (Dict(:id => 1), r"`id` must be a string"),
            (Dict(:id => :SE), r"`id` must be a string"),
            (Dict(:id => nothing), r"`id` must be a string"),
            (Dict(:id => ""), r"`id` must be a nonempty string"),
            (" \t", r"`id` must be a nonempty string"),
            (42, r"must be an object"),
            (nothing, r"must be an object"),
            (Dict(1 => "SE"), r"must use symbol keys"),
            (Dict(:id => "SE", :constraints => nothing), r"`constraints` must be a dictionary"),
            (Dict(:id => "SE", :constraints => []), r"`constraints` must be a dictionary"),
            (Dict(:id => "SE", :constraints => true), r"`constraints` must be a dictionary"),
            (Dict(:id => "SE", :constraints => Dict(:MaxCapacityConstraint => true)), r"requires a .*configuration object"),
        )
        for (entry, message) in invalid_entries
            system, _ = make_system()
            @test_throws message ME.load_locations!(system, @__DIR__, Any["valid", entry])
            @test ME.location_ids(system) == [:valid]
        end
    end
end

@testset "Location commodity definitions" begin
    @testset "Schema, defaults and malformed commodity entries" begin
        @test isempty(ME.LocationInput(; id="SE").commodities)
        @test ME.LocationInput(; id="SE").commodities !== ME.LocationInput(; id="NE").commodities
        @test ME.LocationInput("SE", Dict()).commodities == Dict()
        for value in (nothing, ["Electricity"], "Electricity")
            @test_throws r"`commodities` must be a dictionary" ME.LocationInput(; id="SE", commodities=value)
        end
        for value in (nothing, "Electricity", [])
            @test_throws r"details must be a dictionary" ME.LocationInput(; id="SE", commodities=Dict(:Electricity => value))
        end
        @test_throws r"commodity names must be nonempty" ME.LocationInput(; id="SE", commodities=Dict(Symbol(" ") => Dict()))
        @test_throws r"commodities must use symbol keys" ME.LocationInput(; id="SE", commodities=Dict{Any,Any}(:Electricity => Dict(), "Electricity" => Dict()))
    end

    @testset "Default nodes and existing asset endpoint resolution" begin
        system, _ = make_system(; auto_create_nodes=false)
        entries = JSON3.read("""[{"id":"SE","commodities":{"Electricity":{},"Hydrogen":{}}},"MIDAT"]""")
        ME.load_locations!(system, @__DIR__, entries)
        location = ME.find_locations(system, :SE)
        @test length(ME.get_nodes(system)) == 2
        @test location.nodes[:Electricity].id == :SE_Electricity
        @test location.nodes[:Hydrogen].id == :SE_Hydrogen
        for commodity in (ME.Electricity, ME.Hydrogen)
            node = location.nodes[ME.typesymbol(commodity)]
            @test ME.find_node(system, :SE, commodity) === node
            @test ME.find_node(system, node.id, commodity) === node
            @test node.location == :SE
            @test count(entry -> entry === node, system.locations) == 1
            @test any(constraint -> constraint isa ME.BalanceConstraint, node.constraints)
        end
        asset = ME.make(ME.Electrolyzer, Dict{Symbol,Any}(
            :id => :electrolyzer, :location => :SE,
            :can_expand => false, :can_retire => false,
            :existing_capacity => 20.0, :efficiency_rate => 0.5,
        ), system)
        @test asset.elec_edge.start_vertex === location.nodes[:Electricity]
        @test asset.h2_edge.end_vertex === location.nodes[:Hydrogen]
        @test length(ME.get_nodes(system)) == 2
    end

    @testset "Node details, supply and relative time series" begin
        mktempdir() do directory
            system, _ = make_system()
            system.data_dirpath = directory
            write(joinpath(directory, "demand.csv"), "demand\n12.0\n")
            entries = copy(JSON3.read("""
                [{"id":"SE","commodities":{"Electricity":{
                  "id":"custom_electricity", "location":"SE",
                  "demand":{"timeseries":{"path":"demand.csv","header":"demand"}},
                  "supply":{"grid":{"price":[30.0],"min":[0.0],"max":[100.0]}},
                  "constraints":{"BalanceConstraint":true}
                }}}]
                """))
            original = deepcopy(entries)
            ME.load_locations!(system, directory, entries)
            node = ME.find_node(system, :custom_electricity, ME.Electricity)
            @test node.demand == [12.0]
            @test node.supply[:grid].price == [30.0]
            @test node.supply[:grid].max == [100.0]
            @test node.location == :SE
            @test entries == original
            ME.load!(system, Dict{Symbol,Any}(:type => :Hydrogen, :instance_data => Dict{Symbol,Any}(:id => "h2", :location => "SE")))
            @test ME.find_locations(system, :SE).nodes[:Hydrogen].id == :h2
            @test length(ME.get_nodes(system)) == 2
            write(joinpath(directory, "locations.json"), JSON3.write(Dict(:locations => entries)))
            ME.load_locations!(system, directory, Dict{Symbol,Any}(:path => "locations.json"))
            @test ME.find_node(system, :custom_electricity, ME.Electricity).demand == [12.0]
            @test length(ME.get_nodes(system)) == 1
        end
    end

    @testset "Declared subcommodities" begin
        system, _ = make_system()
        system.commodities[:LocationTestHydrogen] = LocationTestHydrogen
        ME.COMMODITY_TYPES[:LocationTestHydrogen] = LocationTestHydrogen
        system.time_data[:LocationTestHydrogen] = ME.TimeData{LocationTestHydrogen}(;
            time_interval=1:1, hours_per_timestep=1, period_index=1,
            subperiods=[1:1], subperiod_indices=[1], subperiod_weights=Dict(1=>1.0), subperiod_map=Dict(1=>1),
        )
        ME.load_locations!(system, @__DIR__, [Dict(:id=>"SE", :commodities=>Dict(:LocationTestHydrogen=>Dict(), :Hydrogen=>Dict()))])
        location = ME.find_locations(system, :SE)
        @test location.nodes[:LocationTestHydrogen] isa ME.Node{LocationTestHydrogen}
        @test location.nodes[:LocationTestHydrogen].id == :SE_LocationTestHydrogen
        @test length(location.nodes) == 2
    end

    @testset "Registration conflicts" begin
        system, _ = make_system()
        ME.load_locations!(system, @__DIR__, [Dict(:id => "SE", :commodities => Dict(:Electricity => Dict()))])
        location = ME.find_locations(system, :SE)
        independent = Dict{Symbol,Any}(:type => :Electricity, :instance_data => Dict{Symbol,Any}(:id => "another", :location => "SE"))
        @test_throws r"Electricity node already exists" ME.load!(system, independent)
        @test length(ME.get_nodes(system)) == 1
        original = location.nodes[:Electricity]
        duplicate = Dict{Symbol,Any}(:type => :Hydrogen, :instance_data => Dict{Symbol,Any}(:id => "SE_Electricity", :location => "SE"))
        @test_throws r"Duplicate network ID" ME.load!(system, duplicate)
        @test length(ME.get_nodes(system)) == 1
        other = ME.Location(; id=:NE, system=system)
        ME.add!(system, other)
        @test_throws r"already belongs to location" ME.add_node!(other, original)
        @test isempty(other.nodes)
        @test original.location == :SE
        @test_throws r"Duplicate network ID" ME.add!(system, original)
        @test_throws r"Duplicate network ID `SE`" ME.load_locations!(system, @__DIR__, ["SE", "SE"])
        @test ME.location_ids(system) == [:SE]

        for details in (Dict(:location => "NE"), Dict(:type => "Hydrogen"), Dict(:id => ""))
            system, _ = make_system()
            @test_throws ArgumentError ME.load_locations!(system, @__DIR__, [Dict(:id => "SE", :commodities => Dict(:Electricity => details))])
        end
        system, _ = make_system()
        @test_throws r"not defined in the system" ME.load_locations!(system, @__DIR__, [Dict(:id => "SE", :commodities => Dict(:NaturalGas => Dict()))])
        system, _ = make_system()
        delete!(system.time_data, :Electricity)
        @test_throws r"Time data.*is not defined" ME.load_locations!(system, @__DIR__, [Dict(:id => "SE", :commodities => Dict(:Electricity => Dict()))])
        system, _ = make_system()
        @test_throws r"Duplicate network ID" ME.load_locations!(system, @__DIR__, [
            Dict(:id => "SE", :commodities => Dict(:Electricity => Dict(:id => "shared"))),
            Dict(:id => "NE", :commodities => Dict(:Hydrogen => Dict(:id => "shared"))),
        ])
    end

    @testset "A location's nodes are created before the next entry" begin
        system, _ = make_system()
        entries = Any[Dict(:id=>"SE", :commodities=>Dict(:Electricity=>Dict())), Dict()]
        @test_throws r"Location entry 2 requires an `id` field" ME.load_locations!(system, @__DIR__, entries)
        location = ME.find_locations(system, :SE)
        @test location.nodes[:Electricity].id == :SE_Electricity
        @test ME.get_nodes(system) == [location.nodes[:Electricity]]

        entries = [
            Dict(:id=>"SE", :commodities=>Dict(:Electricity=>Dict())),
            Dict(:id=>"SE", :commodities=>Dict(:Hydrogen=>Dict())),
        ]
        @test_throws r"Duplicate network ID `SE`" ME.load_locations!(system, @__DIR__, entries)
        location = ME.find_locations(system, :SE)
        @test Set(keys(location.nodes)) == Set([:Electricity])
        @test ME.get_nodes(system) == [location.nodes[:Electricity]]
    end

    @testset "System generation loads time data before location nodes" begin
        system = ME.empty_system(@__DIR__)
        data = Dict{Symbol,Any}(
            :settings => Dict{Symbol,Any}(:WriteSubcommodities => false),
            :commodities => ["Electricity", "Hydrogen"],
            :time_data => Dict{Symbol,Any}(
                :NumberOfSubperiods => 1, :HoursPerTimeStep => Dict(:Electricity => 1, :Hydrogen => 1),
                :HoursPerSubperiod => Dict(:Electricity => 1, :Hydrogen => 1), :TotalHoursModeled => 1,
            ),
            :locations => [Dict(:id => "SE", :commodities => Dict(:Electricity => Dict(:demand => [3.0])) )],
            :nodes => [Dict{Symbol,Any}(:type => "Hydrogen", :instance_data => Dict{Symbol,Any}(:id => "h2", :location => "SE"))],
            :assets => Dict{Symbol,Any}[],
        )
        ME.generate_system!(system, data)
        @test ME.find_node(system, :SE, ME.Electricity).demand == [3.0]
        @test ME.find_node(system, :SE, ME.Hydrogen).id == :h2
        @test length(ME.get_nodes(system)) == 2
    end
end

@testset "Shared node and location ID namespace" begin
    @testset "Registration checks both directions" begin
        system, location = make_system()
        node = ME.Node{ME.Electricity}(; id=:Boston, timedata=system.time_data[:Electricity])
        @test_throws r"Duplicate network ID `Boston`" ME.add!(system, node)
        @test system.locations == [location]
        @test_throws r"Duplicate network ID `Boston`" ME.add!(system, ME.Location(; id=:Boston, system=system))
        @test system.locations == [location]

        node = ME.Node{ME.Electricity}(; id=:future_location, timedata=system.time_data[:Electricity])
        ME.add!(system, node)
        @test isnothing(ME.find_locations(system, :future_location))
        @test_throws r"Duplicate network ID `future_location`" ME.add!(system, ME.Location(; id=:future_location, system=system))
        @test system.locations == [location, node]
    end

    @testset "Location-file collisions fail regardless of input order" begin
        entries = [
            Dict(:id=>"A", :commodities=>Dict(:Electricity=>Dict(:id=>"B"))),
            Dict(:id=>"B", :commodities=>Dict(:Hydrogen=>Dict())),
        ]
        for locations in (entries, reverse(entries))
            system, _ = make_system()
            @test_throws r"Duplicate network ID `B`" ME.load_locations!(system, @__DIR__, locations)
            @test length(unique(ME.id.(system.locations))) == length(system.locations)
        end
        system, _ = make_system()
        @test_throws r"Duplicate network ID `SE`" ME.load_locations!(system, @__DIR__, [
            Dict(:id=>"SE", :commodities=>Dict(:Electricity=>Dict(:id=>"SE"))),
        ])
    end

    @testset "Automatic locations use system registration" begin
        system, _ = make_system()
        ME.load!(system, Dict{Symbol,Any}(:type=>:Electricity, :instance_data=>Dict{Symbol,Any}(:id=>"source", :location=>"new_location")))
        location = ME.find_locations(system, :new_location)
        @test location isa ME.Location
        @test location.nodes[:Electricity] === ME.find_node(system, :source, ME.Electricity)
        @test_throws r"Duplicate network ID `source`" ME.load!(system, Dict{Symbol,Any}(
            :type=>:Hydrogen, :instance_data=>Dict{Symbol,Any}(:id=>"another_node", :location=>"source"),
        ))
        @test isnothing(ME.find_locations(system, :source))
        @test length(ME.get_nodes(system)) == 1
    end
end

@testset "Symbol-keyed location input contract" begin
    @test_throws r"Location entry 1 must use symbol keys" ME.parse_location_input(Dict("id"=>"SE"))
    @test_throws r"Location constraints must use symbol keys" ME.LocationInput(; id="SE", constraints=Dict("MaxCapacityConstraint"=>false))
    @test_throws r"commodities must use symbol keys" ME.LocationInput(; id="SE", commodities=Dict("Electricity"=>Dict()))
    @test_throws r"details must use symbol keys" ME.LocationInput(; id="SE", commodities=Dict(:Electricity=>Dict("demand"=>[1.0])))

    # Constructor validation does not descend into user-owned extension/config data.
    opaque = Dict("display label"=>Dict("timeseries"=>"extension-owned value"))
    raw = Dict{Symbol,Any}(:id=>"SE", :commodities=>Dict(:Electricity=>Dict(:custom_field=>opaque)),
        :constraints=>Dict(:CustomConstraint=>Dict("payload"=>opaque)))
    original = deepcopy(raw)
    input = ME.parse_location_input(raw)
    @test input.commodities[:Electricity][:custom_field] == opaque
    @test input.constraints[:CustomConstraint]["payload"] == opaque
    @test raw == original

    # Normal JSON input supplies symbol keys at all schema levels and still loads.
    mktempdir() do directory
        write(joinpath(directory, "demand.csv"), "demand\n4.0\n")
        entries = JSON3.read("""[{"id":"SE","commodities":{"Electricity":{
            "demand":{"timeseries":{"path":"demand.csv","header":"demand"}},
            "supply":{"grid":{"price":[30.0],"max":[100.0]}},
            "constraints":{"BalanceConstraint":true}
        }}}]""")
        system, _ = make_system()
        system.data_dirpath = directory
        ME.load_locations!(system, directory, entries)
        node = ME.find_node(system, :SE_Electricity, ME.Electricity)
        @test node.demand == [4.0]
        @test node.supply[:grid].price == [30.0]
        @test node.location == :SE

        # Ordinary Julia dictionaries use the same symbol-key contract.
        details = Dict(:demand=>Dict(:timeseries=>Dict(:path=>"demand.csv", :header=>"demand")))
        ME.load_locations!(system, directory, [Dict(:id=>"SE", :commodities=>Dict(:Electricity=>details))])
        @test ME.find_node(system, :SE_Electricity, ME.Electricity).demand == [4.0]
    end
end

end # module
