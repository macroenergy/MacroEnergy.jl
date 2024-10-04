function get_optimal_asset_capacity(system::System)
    num_assets = length(system.assets)
    asset_ids = Vector{Symbol}(undef, num_assets)
    asset_type = Vector{Symbol}(undef, num_assets)
    asset_vcap = Vector{Float64}(undef, num_assets)
    for i in eachindex(system.assets)
        a = system.assets[i]
        for y in getfield.(Ref(a), fieldnames(typeof(a)))
            if isa(y, AbstractEdge) && has_capacity(y)
                asset_ids[i] = id(a)
                asset_type[i] = Symbol(typeof(a))
                asset_vcap[i] = value(capacity(y))
            end
        end
    end
    return DataFrame(asset = asset_ids, type = asset_type, capacity = asset_vcap)
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
