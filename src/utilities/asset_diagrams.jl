const COMMODITY_COLOURS = Dict{Symbol, String}(
    :Commodity => "#d3b683",   # VeryLightBrown
    :Electricity => "#FFD700", # Gold
    :Alumina => "#E5E5E5",     # LightGray
    :Aluminum => "#A9A9A9",    # DarkGray
    :AluminumScrap => "#A9A9A9", # DarkGray
    :Bauxite => "#8B4513",     # SaddleBrown
    :Biomass => "#6fc276",     # SoftGreen
    :CO2Captured => "#A9A9A9", # DarkGray
    :CO2 => "#A9A9A9",         # DarkGray
    :Cement => "#ffb16d",      # Apricot
    :Coal => "#2F4F4F",        # DarkSlateGray
    :Graphite => "#d5869d",    # DullPink
    :Hydrogen => "#FF69B4",    # HotPink
    :LiquidFuels => "#ff9408", # Tangerine
    :NaturalGas => "#c6fcff",  # LightSkyBlue
    :Uranium => "#4B0082",     # Indigo
)

function random_colour()
    return "#" * join(rand("ABCDEF0123456789", 6))
end

function commodity_colour(commodity::Symbol)
    if haskey(COMMODITY_COLOURS, commodity)
        return COMMODITY_COLOURS[commodity]
    end
    new_colour = random_colour()
    COMMODITY_COLOURS[commodity] = new_colour
    return new_colour
end

function colour_darkness(colour_code::String)
    red = parse(Int16, colour_code[2:3], base=16)
    green = parse(Int16, colour_code[4:5], base=16)
    blue = parse(Int16, colour_code[6:7], base=16)
    return (red * 0.299 + green * 0.587 + blue * 0.114)
end

function dark_color(colour_code::String)
    darkness = colour_darkness(colour_code)
    if darkness < 128
        return true
    else
        return false
    end
end

function mermaid_header()
    return "```mermaid \n %%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%"
end

function mermaid_transform_style(name::String)
    return "style $name fill:black,stroke:black,color:black;"
end

function mermaid_node_style(name::String, fill::String, font_size::Int=21, font_color::String="black")
    return "style $name font-size:$font_size,r:55px,fill:$fill,stroke:black,color:$font_color;"
end

function mermaid_external_node_style(name::String, fill::String, font_size::Int=21, font_color::String="black")
    return "style $name font-size:$font_size,r:55px,fill:$fill,stroke:black,color:$font_color,stroke-dasharray: 3,5;"
end

function mermaid_storage_style(name::String, fill::String, font_size::Int=21, font_color::String="black")
    return "style $name font-size:$font_size,r:55px,fill:$fill,stroke:black,color:$font_color;"
end

function mermaid_edge_style(name::String, number::Int, stroke::String)
    return "linkStyle $number stroke:$stroke,stroke-width: 2px; $name@{ animate: true };"
end

function next_letter(letter::String)
    # This is not very robust, and only works for A -> Z or a -> z
    return string(letter[1] + 1)
end

function calc_font_size(commodity_name::String, default_size::Int=21, trigger_length::Int=10, smallest_size::Int=11)
    return max(smallest_size, min(default_size, default_size - 3 * (length(commodity_name) - trigger_length)))
end

function find_commodities(data::AbstractDict)
    return find_key(data, :commodity)
end

function find_key(data::AbstractDict, target_key)
    commodities = Set{Any}()
    for (key, value) in data
        if key == target_key
            if !ismissing(value) 
                push!(commodities, value)
            end
        elseif isa(value, AbstractDict)
            union!(commodities, find_key(value, target_key))
        end
    end
    return commodities
end

function replace_key(data::AbstractDict, target_key, new_value)
    for (key, value) in data
        if key == target_key
            data[key] = new_value
        elseif isa(value, AbstractDict)
            replace_key(value, target_key, new_value)
        end
    end
    return nothing
end

function find_diagram_name(components::AbstractDict, component_id::Symbol)
    for (field_name, details) in components
        if haskey(details, :id) && details[:id] == component_id
            return details[:diagram_name]
        end
    end
end

function mermaid_parse_vertices!(diagram::String, styling::String, asset_type::Type{<:AbstractAsset}, vertex_name::String)
    components = Dict{Symbol, Dict{Symbol, Any}}()
    if isa(asset_type, UnionAll)
        asset_type = asset_type{Commodity}
    end
    for (name, component) in struct_info(asset_type)
        if component == AbstractAsset
            @info "We can't currently visualize nested assets."
            continue
        elseif component <: AbstractStorage
            commodity = commodity_type(component)
            components[name] = Dict{Symbol, Any}(
                :diagram_name => vertex_name
            )
            commodity_name = string(commodity)
            diagram *= "$(vertex_name)[$commodity_name] \n "
            font_size = calc_font_size(commodity_name)
            fill_color = commodity_colour(Symbol(commodity))
            font_color = dark_color(fill_color) ? "white" : "black"
            styling *= "$(mermaid_storage_style(vertex_name, fill_color, font_size, font_color)) \n "
        elseif component <: Node
            commodity = commodity_type(component)
            components[name] = Dict{Symbol, Any}(
                :diagram_name => vertex_name
            )
            commodity_name = string(commodity)
            diagram *= "$(vertex_name)(($commodity_name)) \n "
            font_size = calc_font_size(commodity_name)
            fill_color = commodity_colour(Symbol(commodity))
            font_color = dark_color(fill_color) ? "white" : "black"
            styling *= "$(mermaid_node_style(vertex_name, fill_color, font_size, font_color)) \n "
        elseif component <: Transformation
            components[name] = Dict{Symbol, Any}(
                :diagram_name => vertex_name
            )
            diagram *= "$(vertex_name){{..}} \n "
            styling *= "$(mermaid_transform_style(vertex_name)) \n "
        end
        vertex_name = next_letter(vertex_name)
    end
    return (diagram, styling, components, vertex_name)
end

function mermaid_diagram(asset_type::Type{<:AbstractAsset}; orientation::String="TB")
    if isa(asset_type, UnionAll)
        UNIONALL_TYPE = true
    else
        UNIONALL_TYPE = false
    end
    vertex_name = "A"
    edge_name = "a"
    edge_numbers = Dict{String, Int}()
    styling = ""
    diagram = "$(mermaid_header())
        flowchart LR
          subgraph \"$asset_type\"
          direction $orientation
    "
    (diagram, styling, components, vertex_name) = mermaid_parse_vertices!(diagram, styling, asset_type, vertex_name)
    data = (!UNIONALL_TYPE && !isempty(asset_type.parameters)) ? default_data(asset_type.name.wrapper, "tmp", "full") : default_data(asset_type, "tmp", "full")
    commodities = find_commodities(data)
    s = empty_system("")
    s.settings = (AutoCreateNodes = true, AutoCreateLocations = true)
    for commodity in commodities
        c_sym = Symbol(commodity)
        c = commodity_types()[c_sym]
        s.time_data[c_sym] = TimeData{c}(; time_interval = 1:1)
    end
    if UNIONALL_TYPE
        push!(commodities, "Commodity")
        s.time_data[:Commodity] = TimeData{Commodity}(; time_interval = 1:1)
        replace_key(data, :commodity, "Commodity")
    end
    if UNIONALL_TYPE || !isempty(asset_type.parameters)
        c = UNIONALL_TYPE ? Commodity : asset_type.parameters[1]
        COMMODITY_TYPES[:Commodity] = Commodity
        s.time_data[Symbol(c)] = TimeData{c}(; time_interval = 1:1)
        replace_key(data, :commodity, string(c))
    end
    tmp = (!UNIONALL_TYPE && !isempty(asset_type.parameters)) ? make(asset_type.name.wrapper, data, s) : make(asset_type, data, s)
    for (field_name, details) in components
        details[:id] = getfield(tmp, field_name).id
    end
    for node in s.locations
        commodity = commodity_type(node)
        components[node.id] = Dict{Symbol, Any}(
            :id => node.id,
            :diagram_name => vertex_name
        )
        commodity_name = string(commodity)
        diagram *= "$(vertex_name)(($commodity_name)) \n "
        font_size = calc_font_size(commodity_name)
        fill_color = commodity_colour(Symbol(commodity))
        font_color = dark_color(fill_color) ? "white" : "black"
        styling *= "$(mermaid_external_node_style(vertex_name, fill_color, font_size, font_color)) \n "
        vertex_name = next_letter(vertex_name)
    end
    for (component, name) in get_components_and_names(tmp)
        if isa(component, AbstractEdge)
            commodity = commodity_type(component)
            edge_numbers[edge_name] = length(edge_numbers)
            diagram *= "$(find_diagram_name(components, component.start_vertex.id)) $edge_name@--$(name)--> $(find_diagram_name(components, component.end_vertex.id)) \n "
            styling *= "$(mermaid_edge_style("$edge_name", edge_numbers[edge_name], commodity_colour(Symbol(commodity)))) \n "
            edge_name = next_letter(edge_name)
        end
    end

    diagram *= "end \n "
    diagram *= styling
    diagram *= "\n```"

    return diagram
end

function save_mermaid_diagram(md_string::String, filepath::AbstractString)
    open(filepath, "w") do f
        write(f, md_string)
    end
end

function mermaid_diagram(asset_type::Type{<:AbstractAsset}, filepath::AbstractString; orientation::String="TB")
    diagram = mermaid_diagram(asset_type; orientation=orientation)
    save_mermaid_diagram(diagram, filepath)
end