    
function add_retrofit_constraints!(system::System, model::Model)    
    # Add retrofitting constraints
    
    retrofit_ids,can_retrofit_edges,is_retrofit_edges = get_unique_retrofit_ids(system)
    @constraint(model, 
    cRetrofitCapacity[retrofit_id in retrofit_ids],
    sum(retrofitted_capacity(e) for e in can_retrofit_edges[retrofit_id]) ==
    sum((new_capacity(e)/retrofit_efficiency(e)) for e in is_retrofit_edges[retrofit_id])
    )

end

function get_unique_retrofit_ids(system::System)
    can_retrofit_ids = Vector{Symbol}()
    is_retrofit_ids = Vector{Symbol}()
    can_retrofit_edges = Dict{Symbol,Vector{AbstractEdge}}()
    is_retrofit_edges = Dict{Symbol,Vector{AbstractEdge}}()
    edges = get_edges(system)
    for e in edges
        if can_retrofit(e)
            push!(can_retrofit_ids, retrofit_id(e))
            if !haskey(can_retrofit_edges, retrofit_id(e))
                can_retrofit_edges[retrofit_id(e)] = [e]
            else
                push!(can_retrofit_edges[retrofit_id(e)], e)
            end
        end
        if is_retrofit(e)
            push!(is_retrofit_ids, retrofit_id(e))
            if !haskey(is_retrofit_edges, retrofit_id(e))
                is_retrofit_edges[retrofit_id(e)] = [e]
            else
                push!(is_retrofit_edges[retrofit_id(e)], e)
            end
        end
    end
    unique_can_retrofit_ids = unique(can_retrofit_ids)
    unique_is_retrofit_ids = unique(is_retrofit_ids)
    # Check if the unique retrofit_ids are the same for can_retrofit and is_retrofit
    @assert isempty(setdiff(unique_can_retrofit_ids,unique_is_retrofit_ids))
    retrofit_ids = unique_is_retrofit_ids
    return retrofit_ids,can_retrofit_edges,is_retrofit_edges
end