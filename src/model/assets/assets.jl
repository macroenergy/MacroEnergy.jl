# utility function to abstract the process of creating an asset
function make_asset(::Type{T}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) where T <: AbstractAsset
    # merge data with default data for the asset
    data = process_asset_data(T, data)
    # get the type of transformation component for the asset
    transformation_type = transformations(T)
    # right now, we only support one transformation type per asset
    length(transformation_type) > 1 && error("Multiple transformation types found for $T")
    transformation = make_transformation(data, time_data)
    # get the type of each tedge component for the asset and make the tedges
    tedge_fields = []
    for (fieldtype,tedge_id) in zip(tedges(T), tedgesnames(T))
        push!(tedge_fields, process_asset_tedge_data(fieldtype, tedge_id, data, time_data, transformation, nodes))
    end
    # add the tedges to the transformation
    transformation.TEdges = Dict{Symbol,AbstractTEdge}(tedgesnames(T) .=> tedge_fields)
    # return the asset with the correct type 
    return T(transformation, tedge_fields...)
end

# utility function to create a tedge component for an asset
function process_asset_tedge_data(::Type{T}, tedge_id::Symbol, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, transformation::AbstractTransform, nodes::Dict{Symbol,Node}) where T <: Union{AbstractTEdge, AbstractTEdgeWithUC}
    commodity = Symbol(commodity_type(T))
    # WARN: tedge_id must match the name of the field in the asset struct
    # get the tedge data using the tedge_id
    tedge_id, tedge_data = get_tedge_data(data, tedge_id)
    isnothing(tedge_data) && error("No edge data found for $T")
    tedge_data[:id] = tedge_id
    # get the node for the tedge using the commodity type
    node = get_node_tedge(data, commodity, nodes)
    # make the tedge
    return make_tedge(tedge_data, time_data, transformation, node)
end

function get_node_tedge(data::Dict{Symbol,Any}, commodity::Symbol, nodes::Dict{Symbol,Node})
    node_id = Symbol(data[:nodes][commodity])
    return nodes[node_id]
end

# utility function to get a vector of the tedge types for an asset
function tedges(::Type{T}) where T <: AbstractAsset
    tedges_ids = findall(x -> x <: AbstractTransformationEdge, fieldtypes(T))
    return fieldtypes(T)[tedges_ids]
end

# utility function to get a vector of the tedge names for an asset
function tedgesnames(::Type{T}) where T <: AbstractAsset
    tedges_ids = findall(x -> x <: AbstractTransformationEdge, fieldtypes(T))
    return Base.fieldnames(T)[tedges_ids]
end

# utility function to get the transformation type for an asset
function transformations(::Type{T}) where T <: AbstractAsset
    transformation_ids = findall(x -> x <: AbstractTransform, fieldtypes(T))
    return fieldtypes(T)[transformation_ids]
end