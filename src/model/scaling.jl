function scaling!(y::Union{AbstractVertex,AbstractEdge})
    atts_vec = attributes_to_scale(y);

    # Scaling: MWh--> GWh, tons --> ktons, $/MWh --> M$/GWh, $/ton --> M$/kton

    for f in atts_vec
        setfield!(y, f, getfield(y, f) / 1e3)
    end

end

function scaling!(a::AbstractAsset)
    for t in fieldnames(typeof(a))
        scaling!(getfield(a, t))
    end
    return nothing
end

function scaling!(system::System)

    scaling!.(system.locations)

    scaling!.(system.assets)

    return nothing
end

function attributes_to_scale(n::Node)
    return [:demand,:max_supply,:price,:price_nsd,:price_supply,:price_unmet_policy,:rhs_policy]
end

function attributes_to_scale(e::Edge)
    return [:capacity_size,:existing_capacity,:fixed_om_cost,:investment_cost,:max_capacity,:min_capacity,:variable_om_cost]
end

function attributes_to_scale(e::EdgeWithUC)
    return [:capacity_size,:existing_capacity,:fixed_om_cost,:investment_cost,:max_capacity,:min_capacity,:variable_om_cost,:startup_cost]
end

function attributes_to_scale(g::Storage)
    return [:existing_capacity_storage,:fixed_om_cost_storage,:investment_cost_storage,:max_capacity_storage,:min_capacity_storage]
end

function attributes_to_scale(t::Transformation)
    return Symbol[]
end


function /(d::Dict,a::Float64)
    for (k,v) in d
        d[k] = v / a
    end
    return d
end