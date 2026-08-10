const COMMODITY_TYPES = Dict{Symbol,DataType}()

function register_commodity_types!(m::Module = MacroEnergy)
    empty!(COMMODITY_TYPES)
    for (commodity_name, commodity_type) in all_subtypes(m, :Commodity)
        COMMODITY_TYPES[commodity_name] = commodity_type
    end
end

function commodity_types(m::Module = MacroEnergy)
    isempty(COMMODITY_TYPES) && register_commodity_types!(m)
    return COMMODITY_TYPES
end

###### ###### ###### ######

function clean_line(line::AbstractString)::String
    return join(split(strip(line)), " ")
end

function make_commodity(new_commodity::Union{String,Symbol}, m::Module = MacroEnergy)::String
    s = "abstract type $new_commodity <: $m.Commodity end"
    Core.eval(m, Meta.parse(s))
    return s
end

function make_commodity(new_commodity::Union{String,Symbol}, parent_type::Union{String,Symbol}, m::Module = MacroEnergy)::String
    s = "abstract type $new_commodity <: $m.$parent_type end"
    Core.eval(m, Meta.parse(s))
    return s
end

function make_commodity(new_commodity::Union{String,Symbol}, parent_type::DataType, m::Module = MacroEnergy)::String
    return make_commodity(new_commodity, typesymbol(parent_type), m)
end

###### ###### ###### ######

function load_commodities_from_file(
    path::AbstractString,
    rel_path::AbstractString;
    write_subcommodities::Bool=false,
    allow_implicit_top_level_commodities::Bool=true,
)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "commodities.json")
    end
    # read in the list of commodities from the data directory
    isfile(path) || error("Commodity data not found at $(abspath(path))")
    return load_commodities(
        copy(read_json(path)),
        rel_path;
        write_subcommodities=write_subcommodities,
        allow_implicit_top_level_commodities=allow_implicit_top_level_commodities,
    )
end

function load_commodities(
    data::AbstractDict{Symbol,Any},
    rel_path::AbstractString;
    write_subcommodities::Bool=false,
    allow_implicit_top_level_commodities::Bool=true,
)
    if haskey(data, :path)
        path = rel_or_abs_path(data[:path], rel_path)
        return load_commodities_from_file(
            path,
            rel_path;
            write_subcommodities=write_subcommodities,
            allow_implicit_top_level_commodities=allow_implicit_top_level_commodities,
        )
    elseif haskey(data, :commodities)
        return load_commodities(
            data[:commodities],
            rel_path;
            write_subcommodities=write_subcommodities,
            allow_implicit_top_level_commodities=allow_implicit_top_level_commodities,
        )
    end
    return nothing
end

function load_commodities(
    data::AbstractVector{Dict{Symbol,Any}},
    rel_path::AbstractString;
    write_subcommodities::Bool=false,
    allow_implicit_top_level_commodities::Bool=true,
)
    for item in data
        if isa(item, AbstractDict{Symbol,Any}) && haskey(item, :commodities)
            return load_commodities(
                item,
                rel_path;
                write_subcommodities=write_subcommodities,
                allow_implicit_top_level_commodities=allow_implicit_top_level_commodities,
            )
        end
    end
    error("Commodity data not found or incorrectly formatted in system_data")
end

function load_commodities(
    data::AbstractVector{<:AbstractString},
    rel_path::AbstractString;
    write_subcommodities::Bool=false,
    allow_implicit_top_level_commodities::Bool=true,
)
    # Probably means we have a vector of commdity types
    return load_commodities(
        Symbol.(data),
        rel_path;
        write_subcommodities=write_subcommodities,
        allow_implicit_top_level_commodities=allow_implicit_top_level_commodities,
    )
end

function parse_commodity_inputs(
    commodities::AbstractVector{<:Any},
    macro_commodities::AbstractDict{Symbol,DataType},
    allow_implicit_top_level_commodities::Bool,
)
    user_commodities = Dict{Symbol,Any}[]
    top_level_user_commodities = Symbol[]
    top_level_seen = Set{Symbol}()
    system_commodities = Symbol[]

    for commodity in commodities
        if isa(commodity, Symbol)
            if commodity ∉ keys(macro_commodities)
                if !allow_implicit_top_level_commodities
                    error("Unknown commodity: $commodity")
                end
                if commodity ∉ top_level_seen
                    @debug("Unknown commodity $(commodity) treated as new top-level commodity (<: Commodity). Check for typos if this was not intended.")
                    push!(top_level_user_commodities, commodity)
                    push!(top_level_seen, commodity)
                end
            end
            push!(system_commodities, commodity)
        elseif isa(commodity, AbstractString)
            commodity_symbol = Symbol(commodity)
            if commodity_symbol ∉ keys(macro_commodities)
                if !allow_implicit_top_level_commodities
                    error("Unknown commodity: $commodity")
                end
                if commodity_symbol ∉ top_level_seen
                    @debug("Unknown commodity $(commodity) treated as new top-level commodity (<: Commodity). Check for typos if this was not intended.")
                    push!(top_level_user_commodities, commodity_symbol)
                    push!(top_level_seen, commodity_symbol)
                end
            end
            push!(system_commodities, commodity_symbol)
        elseif isa(commodity, Dict) && haskey(commodity, :name) && haskey(commodity, :acts_like)
            push!(user_commodities, commodity)
            push!(system_commodities, Symbol(commodity[:name]))
        else
            error("Invalid commodity format: $commodity")
        end
    end

    return user_commodities, top_level_user_commodities, system_commodities
end

function add_top_level_commodity!(
    commodity_name::Symbol,
    commodity_keys,
    subcommodities_lines::AbstractVector{String};
    write_subcommodities::Bool=false,
 )::Bool
    if commodity_name in commodity_keys
        return false
    end
    @debug("Adding top-level user commodity $(commodity_name)")
    commodity_line = make_commodity(commodity_name)
    COMMODITY_TYPES[commodity_name] = Base.invokelatest(getfield, MacroEnergy, commodity_name)
    if write_subcommodities
        @debug("Will write top-level user commodity $(commodity_name) to file")
        push!(subcommodities_lines, commodity_line)
    end
    return true
end

function add_top_level_commodities!(
    top_level_user_commodities::AbstractVector{Symbol},
    subcommodities_lines::AbstractVector{String};
    write_subcommodities::Bool=false,
)
    added_top_level = Symbol[]
    commodity_keys = keys(commodity_types())
    for commodity_name in top_level_user_commodities
        was_added = add_top_level_commodity!(
            commodity_name,
            commodity_keys,
            subcommodities_lines;
            write_subcommodities=write_subcommodities,
        )
        if was_added
            push!(added_top_level, commodity_name)
        end
    end
    return added_top_level
end

function add_subcommodity!(
    commodity::AbstractDict{Symbol,Any},
    commodity_keys,
    added_subcommodities::AbstractVector{Symbol},
    subcommodities_lines::AbstractVector{String};
    write_subcommodities::Bool=false,
)::Bool
    @debug("Iterating over user-defined subcommodities")
    new_name = Symbol(commodity[:name])
    parent_name = Symbol(commodity[:acts_like])

    if new_name in commodity_keys
        @debug("Commodity $(commodity[:name]) already exists")
        return true
    end

    if parent_name ∉ commodity_keys
        return false
    end

    @debug("Adding subcommodity $(new_name), which acts like commodity $(parent_name)")
    commodity_line = make_commodity(new_name, parent_name)
    COMMODITY_TYPES[new_name] = Base.invokelatest(getfield, MacroEnergy, new_name)
    push!(added_subcommodities, new_name)
    if write_subcommodities
        @debug("Will write subcommodity $(new_name) to file")
        push!(subcommodities_lines, commodity_line)
    end
    return true
end

function resolve_subcommodities!(
    user_commodities::AbstractVector{<:AbstractDict{Symbol,Any}},
    subcommodities_lines::AbstractVector{String};
    write_subcommodities::Bool=false,
)
    added_subcommodities = Symbol[]
    unresolved = collect(user_commodities)

    while !isempty(unresolved)
        progress = false
        next_unresolved = Dict{Symbol,Any}[]
        commodity_keys = keys(commodity_types())

        for commodity in unresolved
            was_resolved = add_subcommodity!(
                commodity,
                commodity_keys,
                added_subcommodities,
                subcommodities_lines;
                write_subcommodities=write_subcommodities,
            )
            if was_resolved
                progress = true
            else
                push!(next_unresolved, commodity)
            end
        end

        if !progress
            unknown_parents = unique(Symbol(c[:acts_like]) for c in unresolved)
            error("Unknown or circular parent commodities: $unknown_parents")
        end

        unresolved = next_unresolved
    end

    return added_subcommodities
end

function load_commodities(
    commodities::AbstractVector{<:Any},
    rel_path::AbstractString="";
    write_subcommodities::Bool=false,
    allow_implicit_top_level_commodities::Bool=true,
)
    register_commodity_types!()

    macro_commodities = commodity_types()
    all_sub_commodities, top_level_user_commodities, system_commodities =
        parse_commodity_inputs(commodities, macro_commodities, allow_implicit_top_level_commodities)

    subcommodities_lines = String[]
    added_top_level_commodities = add_top_level_commodities!(
        top_level_user_commodities,
        subcommodities_lines;
        write_subcommodities=write_subcommodities,
    )
    added_subcommodities = resolve_subcommodities!(
        all_sub_commodities,
        subcommodities_lines;
        write_subcommodities=write_subcommodities,
    )

    @info(" ++ Added user commodities: $(length(added_top_level_commodities)) top-level, $(length(added_subcommodities)) subcommodities")
    !isempty(added_top_level_commodities) && @debug(" -- Added top-level commodities: $(added_top_level_commodities)")
    !isempty(added_subcommodities) && @debug(" -- Added subcommodities: $(added_subcommodities)")
    @debug(" -- Done adding subcommodities")

    if write_subcommodities && !isempty(subcommodities_lines)
        write_user_commodities(rel_path, subcommodities_lines)
        @debug(" -- Done writing subcommodities")
    end
    # get the list of all commodities available
    macro_commodity_types = commodity_types();
    # return a dictionary of system commodities Dict{Symbol, DataType}
    return Dict(k=>macro_commodity_types[k] for k in system_commodities)
end

load_commodities(commodities::AbstractVector{<:AbstractString}) =
    load_commodities(Symbol.(commodities))

function load_commodities(commodities::Vector{Symbol})
    # get the list of all commodities available
    macro_commodities = commodity_types()

    validate_commodities(commodities)

    # return a dictionary of commodities Dict{Symbol, DataType}
    filter!(((key, _),) -> key in commodities, macro_commodities)
    return macro_commodities
end

###### ###### ###### ######

function validate_commodities(
    commodities,
    macro_commodities::Dict{Symbol,DataType} = commodity_types(MacroEnergy),
)
    if any(commodity -> commodity ∉ keys(macro_commodities), commodities)
        error("Unknown commodities: $(setdiff(commodities, keys(macro_commodities)))")
    end
    return nothing
end

function load_subcommodities_from_file(path::AbstractString=pwd())
    subcommodities_path = joinpath(path, "tmp","subcommodities.jl")
    if isfile(subcommodities_path)
        @info(" ++ Loading pre-defined user commodities")
        @debug(" -- Loading subcommodities from file $(subcommodities_path)")
        include(subcommodities_path)
    end
    return subcommodities_path
end