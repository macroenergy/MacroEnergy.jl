module TestTemplateLocation

using Test, JSON3
import MacroEnergy as ME

same_input(left, right) = ME.mutable_json_data(left) == ME.mutable_json_data(right)

function rich_location()
    return Dict{Symbol,Any}(
        :id => "SE",
        :commodities => Dict(:Electricity => Dict(
            :demand => Dict(:timeseries => Dict(:path => "future_demand.csv", :header => "demand")),
        )),
        :constraints => Dict(:MaxCapacityConstraint => Dict(:VRE => Dict(:edge => "edge", :value => 300.0))),
        :custom => Dict("display label" => "South East"),
    )
end

@testset "Location templates" begin
    @testset "Single-entry core preserves raw definitions" begin
        original = rich_location()
        document = Dict{Symbol,Any}(:locations => [deepcopy(original)], :metadata => "keep")
        @test isnothing(ME.add_location_template!(document, "NE"))
        @test document[:locations] == Any[original, "NE"]
        for entry in ("SE", Dict(:id => "SE"), deepcopy(original))
            ME.add_location_template!(document, entry)
            @test document[:locations] == Any[original, "NE"]
        end
        @test document[:metadata] == "keep"
        conflicting = deepcopy(original)
        conflicting[:custom]["display label"] = "different"
        @test_throws r"already exists with a different definition" ME.add_location_template!(document, conflicting)
        @test document[:locations][1] == original

        new_entry = Dict(:id => "NW", :custom => Dict("label" => "original"))
        ME.add_location_template!(document, new_entry)
        new_entry[:custom]["label"] = "changed"
        @test document[:locations][3][:custom]["label"] == "original"
    end

    @testset "Object-only files and mixed batches round-trip" begin
        mktempdir() do root
            path = joinpath(root, "locations.json")
            original = rich_location()
            ME.write_json(path, Dict(:locations => [original], :metadata => Dict("label" => "keep")))
            @test isnothing(ME.template_location(path, "NE"; make_file=false))
            ME.template_location(path, Any["SE", deepcopy(original), Dict(:id => "MIDAT"), "NE", "MIDAT"])
            document = copy(ME.read_json(path))
            @test same_input(document[:locations], Any[original, "NE", Dict(:id => "MIDAT")])
            @test document[:metadata] == Dict(:label => "keep")

            parsed = JSON3.read("""{"id":"H2","commodities":{"Hydrogen":{}},"extension":{"label":"keep"}}""")
            ME.template_location(path, parsed)
            @test copy(ME.read_json(path))[:locations][4] == copy(parsed)
            @test parsed[:commodities][:Hydrogen] == Dict()

            symbol_values = Dict(:id => "SYMBOLS", :commodities => Dict(:Electricity => Dict(
                :id => :symbol_node, :demand => Dict(:timeseries => Dict(:path => "future.csv", :header => :demand)),
            )))
            ME.template_location(path, symbol_values)
            @test isnothing(ME.template_location(path, deepcopy(symbol_values)))
            @test length(ME.read_json(path)[:locations]) == 5
            @test ME.read_json(path)[:locations][5][:commodities][:Electricity][:id] == "symbol_node"
        end
    end

    @testset "Invalid requests leave existing files unchanged" begin
        mktempdir() do root
            path = joinpath(root, "locations.json")
            original = rich_location()
            ME.write_json(path, Dict(:locations => Any[original, "NE"]))
            before = read(path)
            for entries in (
                Any["new", Dict(:id => "SE", :commodities => Dict(:Hydrogen => Dict()))],
                Any["new", Dict()],
                Any["new", " \t"],
                Any["new", 1],
                Any["new", Dict("id" => "string keys")],
                Any["new", Dict(:id => "bad", :commodities => ["Electricity"])],
            )
                @test_throws ArgumentError ME.template_location(path, entries)
                @test read(path) == before
            end
            for entries in (Any["SE", Dict(:id => "SE")], Any[Dict()], "SE")
                ME.write_json(path, Dict(:locations => entries))
                before = read(path)
                @test_throws ArgumentError ME.template_location(path, "new")
                @test read(path) == before
            end
        end
    end

    @testset "New files, directories and compressed files" begin
        mktempdir() do root
            file = joinpath(root, "nested", "locations.json")
            @test_throws r"Location file does not exist" ME.template_location(file, "SE"; make_file=false)
            @test !ispath(dirname(file))
            ME.template_location(file, "SE")
            @test copy(ME.read_json(file))[:locations] == ["SE"]
            @test !isdir(file)

            directory = joinpath(root, "directory")
            ME.template_location(directory, ["SE", "SE", "NE"])
            @test copy(ME.read_json(joinpath(directory, "locations.json")))[:locations] == ["SE", "NE"]

            compressed = joinpath(root, "locations.json.gz")
            ME.template_location(compressed, rich_location())
            ME.template_location(compressed, "NE")
            @test same_input(copy(ME.read_json(compressed))[:locations], Any[rich_location(), "NE"])

            invalid = joinpath(root, "invalid", "locations.json")
            @test_throws ArgumentError ME.template_location(invalid, Any["SE", Dict()])
            @test !ispath(dirname(invalid))
        end
    end

    @testset "System wrappers and extracted template modules" begin
        mktempdir() do root
            system = ME.template_system(joinpath(root, "case"))
            ME.template_location(system, "SE"; style="full", format="json")
            entry = rich_location()
            entry[:id] = "NE"
            ME.template_location(system, entry)
            ME.template_location(system, Any["SE", deepcopy(entry), "MIDAT"])
            file = joinpath(system.data_dirpath, "system", "locations.json")
            @test same_input(copy(ME.read_json(file))[:locations], Any["SE", entry, "MIDAT"])
            ME.template_node(system, ME.Electricity)
            @test length(ME.read_json(joinpath(system.data_dirpath, "system", "nodes.json"))[:nodes]) == 1
        end
    end

    @testset "IO writer leaves ownership with caller" begin
        document = Dict{Symbol,Any}(:locations => Any[])
        rich = rich_location()
        rich[:id] = "NE"
        for entry in ("SE", rich)
            ME.add_location_template!(document, entry)
        end
        buffer = IOBuffer()
        @test isnothing(ME.write_json(buffer, document))
        @test isopen(buffer)
        @test same_input(copy(JSON3.read(String(take!(buffer)))), document)
        @test isnothing(ME.write_json(buffer, Dict(:value => Inf)))
        @test JSON3.read(String(take!(buffer)); allow_inf=true)[:value] == Inf
        @test isopen(buffer)
    end
end

end # module
