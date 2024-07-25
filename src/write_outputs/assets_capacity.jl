function get_optimal_asset_capacity(assets::Dict{Symbol, AbstractAsset})
    capacity_results = Dict{Symbol,Dict{Symbol,Float64}}();
    for k in keys(assets)
        for f in fieldnames(assets[k])
            y = getproperty(assets[k],f);
            if isa(y,AbstractTransform)
                if has_storage(y)
                    vcap = value(capacity_storage(y));
                    if vcap!=0
                        capacity_results[k] = Dict(f=>vcap)
                    end
                end
            elseif  has_planning_variables(y)
                vcap = value(capacity(y));
                if vcap!=0
                    capacity_results[k] = Dict(f=>vcap)
                end
            end
        end
    end
    return capacity_results

end