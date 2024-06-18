using JSON3
using InteractiveUtils


function load_assets_json(data_dir::AbstractString, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    #=============================================
    This function does the following:
        - Makes a Dict{Symbol,AbstractAsset}() entry for each instance of an asset
    It would be more efficient to do both steps together for each entry,
    but this way allows someone to just to the second step with their own data
    or inject other actions along the way for individual inputs or transformations.
    =============================================#
    # Make a list of all the .JSON files in the data directory
    files = filter(x -> endswith(x, ".json"), readdir(data_dir))
    # Make empty Dict of transformation data
    assets = Dict{Symbol,AbstractAsset}()
    # For each file, load the JSON, extract the transformation data
    # and make the transformation
    for file in files
        data = JSON3.read(joinpath(data_dir, file))
        load_assets!(assets, data, time_data, nodes)
    end
    return assets
end

function load_assets!(
    asset_data::Dict{Symbol,AbstractAsset},
    data::JSON3.Object,
    time_data::Dict{Symbol,TimeData},
    nodes::Dict{Symbol,Node}
)
    for (a_name, a_data) in data
        # Get the TransformationType.
        #=============================================
        The :type key is currently outside of the global and instance data
        so there can only be one TransformationType.
        We could change that, but it would mean different transformations
        sharing costs and / or lists of nodes, which would be odd.
        =============================================#
        sanitize_json!(a_data)
        a_type = asset_types()[Symbol(a_data[:type])]
        # Check if there are multiple instance_data inputs for this transformation
        if typeof(a_data[:instance]) == JSON3.Object
            # If only one, get the inputs, assign an ID, and make the transformation
            instance_data = assets_instance_data(a_data[:global], a_data[:instance])
            haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = a_name
            instance_data[:id], _ = make_asset_id(instance_id, asset_data)
            asset_data[instance_data[:id]] = make_asset(a_type, instance_data, time_data, nodes)
        else
            # Otherwise, loop over the instance_data inputs and do the same for each
            for (instance_idx, instance_data) in enumerate(a_data[:instance])
                instance_data = assets_instance_data(a_data[:global], instance_data)
                haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_asset_name(instance_idx, a_name)
                instance_data[:id], _ = make_asset_id(instance_id, asset_data)
                asset_data[instance_data[:id]] = make_asset(a_type, instance_data, time_data, nodes)
            end
        end
    end
end

function assets_instance_data(
    global_data::AbstractDict{Symbol,Any},
    instance_data::AbstractDict{Symbol,Any}
)
    # Merge global and node data, with node data overwriting global data
    instance_data = merge(global_data, instance_data)

    validate_data!(instance_data)

    return instance_data
end

function default_asset_name(instance_name::T, a_name::T) where T<:Union{AbstractString,Symbol}
    return Symbol(string(instance_name, "_", a_name))
end

function make_asset_id(id::Symbol, assets::Dict{Symbol,AbstractAsset}, count::UInt8=UInt8(1))
    existing_ids = collect(keys(assets))

    if !(id in existing_ids)
        return id, count
    end

    while Symbol(string(id, "_", count)) in existing_ids
        count += UInt8(1)
    end
    return Symbol(string(id, "_", count)), count
end

function all_subtypes(m::Module, type::Symbol)::Dict{Symbol,DataType}
    types = Dict{Symbol,DataType}()
    for type in subtypes(getfield(m, type))
        all_subtypes!(types, type)
    end
    return types
end

function all_subtypes!(types::Dict{Symbol,DataType}, type::DataType)
    types[Symbol(type)] = type
    if !isempty(subtypes(type))
        for subtype in subtypes(type)
            all_subtypes!(types, subtype)
        end
    end
    return nothing
end

function transformation_types(m::Module=Macro)
    return all_subtypes(m, :AbstractTransform)
end

function asset_types(m::Module=Macro)
    return all_subtypes(m, :AbstractAsset)
end

function constraint_types(m::Module=Macro)
    return all_subtypes(m, :AbstractTypeConstraint)
end

function commodity_types(m::Module=Macro)
    return all_subtypes(m, :Commodity)
end

function sanitize_json!(data::JSON3.Object)
    required_keys = Symbol[
        :type,
    ]
    paired_keys = Dict{Symbol,Symbol}(
        :global => :instance
    )
    # If any required are missing, throw an error
    for key in required_keys
        if !haskey(data, key)
            error("Missing key: $key")
        end
    end

    # For each paired key, if one is missing, add an empty Dict{Symbol,Any}
    # If both are missing, throw an error
    for (key_1, key_2) in paired_keys
        key_1_missing = !haskey(data, key_1)
        key_2_missing = !haskey(data, key_2)
        if key_1_missing && !key_2_missing
            data[key_1] = Dict{Symbol,Any}()
        elseif !key_1_missing && key_2_missing
            data[key_2] = Dict{Symbol,Any}()
        elseif key_1_missing && key_2_missing
            error("Missing key: $key_1 or $key_2")
        end
    end
    return nothing
end

function make_asset(::Type{NaturalGasPower}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    #=============================================
    This function makes a NaturalGasPower from the data Dict.
    It is a helper function for load_assets!.
    =============================================#
    # Make the NaturalGasPower
    natgaspower = make_natgaspower(data, time_data, nodes)
    return natgaspower
end

function make_asset(::Type{SolarPV}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    #=============================================
    This function makes a SolarPV from the data Dict.
    It is a helper function for load_assets!.
    =============================================#
    # Make the SolarPV
    node_out_id = Symbol(data[:nodes][:Electricity])
    node_out = nodes[node_out_id]
    solar_pv = make_solarpv(data, time_data, node_out)
    return solar_pv
end

function make_asset(::Type{Battery}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    #=============================================
    This function makes a Battery from the data Dict.
    It is a helper function for load_assets!.
    =============================================#
    # Make the Battery
    battery = make_battery(data, time_data, nodes)
    return battery
end

function make_asset(::Type{Electrolyzer}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    #=============================================
    This function makes a Electrolyzer from the data Dict.
    It is a helper function for load_assets!.
    =============================================#
    # Make the Electrolyzer
    electrolyzer = make_electrolyzer(data, time_data, nodes)
    return electrolyzer
end