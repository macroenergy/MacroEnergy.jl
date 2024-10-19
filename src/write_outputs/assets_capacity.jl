function get_optimal_asset_capacity(system::System)
    num_assets = length(system.assets)
    asset_ids = Vector{Symbol}(undef, num_assets)
    asset_type = Vector{Symbol}(undef, num_assets)
    asset_vcap = Vector{Float64}(undef, num_assets)
    asset_new_units = Vector{Float64}(undef, num_assets)
    asset_ret_units = Vector{Float64}(undef, num_assets)  

    if system.settings.Scaling
        scaling_factor = 1e3;
    else
        scaling_factor = 1;
    end

    for i in eachindex(system.assets)
        a = system.assets[i]
        for y in getfield.(Ref(a), fieldnames(typeof(a)))
            if isa(y, AbstractEdge) && has_capacity(y)
                asset_ids[i] = id(a)
                asset_type[i] = Symbol(typeof(a))
                asset_vcap[i] = value(capacity(y))*scaling_factor                
                asset_new_units[i] = value(new_capacity(y));
                asset_ret_units[i] = value(ret_capacity(y)); 
            end
        end
    end
    return DataFrame(asset = asset_ids, type = asset_type, capacity = asset_vcap, additions = asset_new_units, retirements = asset_ret_units)
end

# 27% increase in performance
# function get_optimal_asset_capacity(system::System)
#     # vector of tuples (id, type, capacity)
#     asset_capacity = [(id(a), Symbol(typeof(a)), value(capacity(y)))
#                       for a in system.assets
#                       for y in getfield.(Ref(a), fieldnames(typeof(a)))
#                       if isa(y, AbstractEdge) && has_capacity(y)]

#     # create DataFrame from vector of tuples
#     DataFrame((; id, type, cap) for (id, type, cap) in asset_capacity)
# end
