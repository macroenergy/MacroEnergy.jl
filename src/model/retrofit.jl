    
function make_retrofit_options(system::System, data::Dict{Symbol,Any})
    # Make retrofitting assets for assets with retrofit_options
    if haskey(data[:instance_data], :retrofit_options)
        retrofit_id_list = []

        for retrofit_option_data in data[:instance_data][:retrofit_options]
            retrofit_id = Symbol(retrofit_option_data[:id]) # Set the retrofit_id to be the id of the retrofit option, make sure is Symbol
            push!(retrofit_id_list, retrofit_id)

            # Copy template asset and merge data from retrofitting option
            template_asset = Symbol(retrofit_option_data[:template_id])
            template_asset_data = get_input_data_by_id(system, template_asset)
            retrofit_data = recursive_merge(template_asset_data, retrofit_option_data)

            # Make changes to the retrofitting edge
            for (edge, attributes) in retrofit_data[:edges]
                if get(attributes, :can_retrofit, false)
                    attributes[:can_retrofit] = false # Make sure can_retrofit is false
                end
                if get(attributes, :is_retrofit, false)
                    attributes[:retrofit_id] = [retrofit_id] # Adds the retrofit_id to the retrofitting edge
                    attributes[:can_expand] = true # Make sure retroftting edge can expand
                end
            end
            
            # Add the retrofitting asset to the system
            add!(system, make(retrofit_data[:type], retrofit_data, system))

        end

        # Add the retrofit_ids to the asset that can be retrofitted
        for (edge, attributes) in data[:instance_data][:edges]
            if get(attributes, :can_retrofit, false)
                attributes[:retrofit_id] = retrofit_id_list
            end
        end

    end

end 

function add_retrofit_constraints!(system::System, period_idx::Int, model::Model)    
    # Add retrofitting constraints
    
    can_retrofit_edges,is_retrofit_edges = get_retrofit_edges(system)
    
    @constraint(model, [edge_id in keys(can_retrofit_edges)],
        retrofitted_capacity(can_retrofit_edges[edge_id]) ==
        sum(new_capacity(is_retrofit_edges[retrofit_id]) / retrofit_efficiency(is_retrofit_edges[retrofit_id])
        for retrofit_id in retrofit_id(can_retrofit_edges[edge_id])),
        base_name = "cRetrofitCapacity_period$(period_idx)" 
    )

end

function get_retrofit_edges(system::System)
    can_retrofit_edges = Dict{Symbol,AbstractEdge}()
    is_retrofit_edges = Dict{Symbol,AbstractEdge}()
    edges = get_edges(system)
    for e in edges
        if can_retrofit(e) && !ismissing(retrofit_id(e))
            can_retrofit_edges[e.id] = e
        end
        if is_retrofit(e) && !ismissing(retrofit_id(e))
            is_retrofit_edges[retrofit_id(e)[1]] = e
        end
    end
    return can_retrofit_edges, is_retrofit_edges
end