"""
Investment credit of a component in model units, `(pv, cf)` as in `compute_investment_cost`;
positive for credit payments.
"""
function compute_investment_credit(o::Union{AbstractEdge,AbstractStorage})::NTuple{2,Float64}
    rate = investment_credit_rate(o)
    iszero(rate) && return (0.0, 0.0)
    inv_pv, inv_cf = compute_investment_cost(o)
    return (rate * inv_pv, rate * inv_cf)
end

function empty_investment_credits()
    return DataFrame(period=Int[], resource_id=String[], component_id=String[],
        zone=String[], type=String[], tags=String[], commodity=String[],
        investment_credit_rate=Float64[], credited_capacity=Float64[],
        overnight_credit=Float64[], annual_payment=Float64[],
        period_payment=Float64[], discounted_payment=Float64[])
end

"""Extract investment credits in original units, one row per resource and credited component."""
function get_investment_credits(system::System, settings::NamedTuple, scaling::Float64)
    # cf_period_* attributes are needed for the undiscounted payment.
    undo_discount_fixed_costs!(system, settings)
    result = empty_investment_credits()
    period = period_index(system)
    discount_factor = present_value_factor(settings.DiscountRate, total_years(settings.PeriodLengths[1:period-1]))
    tags = Dict(id(a) => format_asset_tags(a) for a in system.assets)
    edges, edge_asset_map = get_edges(system, return_ids_map=true)
    storages, storage_asset_map = get_storages(system, return_ids_map=true)
    for (components, asset_map) in ((edges, edge_asset_map), (storages, storage_asset_map)), o in components
        rate = investment_credit_rate(o)
        (iszero(rate) || !has_capacity(o) || !can_expand(o)) && continue
        asset = asset_map[id(o)]
        asset = asset isa Ref ? asset[] : asset
        credited_capacity = value(new_capacity(o))
        credit_pv, credit_cf = compute_investment_credit(o)
        push!(result, (period, string(id(asset)), string(id(o)), get_zone_name(o),
            get_type(asset), get(tags, id(asset), ""), string(get_commodity_name(o)),
            rate, credited_capacity * scaling,
            rate * investment_cost(o) * credited_capacity * scaling^2,
            rate * annualized_investment_cost(o) * credited_capacity * scaling^2,
            credit_cf * scaling^2, credit_pv * discount_factor * scaling^2))
    end
    return result
end

function write_investment_credits(path::AbstractString, credits::DataFrame)
    write_dataframe(path, credits)
    return credits
end

write_investment_credits(path::AbstractString, system::System, settings::NamedTuple, scaling::Float64) =
    write_investment_credits(path, get_investment_credits(system, settings, scaling))
