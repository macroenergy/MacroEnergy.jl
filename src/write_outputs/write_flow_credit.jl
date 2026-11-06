"""Annual weighted flow credit payment in model units; positive for credit payments."""
function compute_flow_credit_payment(e::AbstractEdge)::Float64
    iszero(flow_credit_rate(e)) && return 0.0
    return flow_credit_rate(e) * sum(subperiod_weight(e, current_subperiod(e, t)) * value(flow(e, t)) for t in time_interval(e))
end

function empty_flow_credits()
    return DataFrame(period=Int[], resource_id=String[], edge_id=String[],
        zone=String[], type=String[], tags=String[], commodity=String[],
        flow_unit=Union{Missing,String}[], flow_credit_rate=Float64[],
        credited_flow=Float64[], annual_payment=Float64[])
end

"""Extract annual payments in original units, preserving each resource and edge."""
function get_flow_credits(system::System, scaling::Float64)
    result = empty_flow_credits()
    edges, asset_map = get_edges(system, return_ids_map=true)
    tags = Dict(id(a) => format_asset_tags(a) for a in system.assets)
    for e in edges
        iszero(flow_credit_rate(e)) && continue
        asset = asset_map[id(e)]
        asset = asset isa Ref ? asset[] : asset
        credited_flow = sum(subperiod_weight(e, current_subperiod(e, t)) * value(flow(e, t)) for t in time_interval(e))
        push!(result, (period_index(e), string(id(asset)), string(id(e)), get_zone_name(e),
            get_type(asset), get(tags, id(asset), ""), string(typesymbol(commodity_type(e))),
            flow_credit_unit(commodity_type(e)), flow_credit_rate(e) * scaling,
            credited_flow * scaling, flow_credit_rate(e) * credited_flow * scaling^2))
    end
    return result
end

"""Aggregate subperiods while retaining resource/vintage and edge identity."""
function aggregate_flow_credits(frames::Vector{DataFrame})
    nonempty = filter(!isempty, frames)
    isempty(nonempty) && return empty_flow_credits()
    data = reduce(vcat, nonempty)
    keys = [:period, :resource_id, :edge_id, :zone, :type, :tags, :commodity, :flow_unit, :flow_credit_rate]
    return combine(groupby(data, keys),
        :credited_flow => sum => :credited_flow,
        :annual_payment => sum => :annual_payment)
end

function write_flow_credits(path::AbstractString, annual::DataFrame, settings::NamedTuple)
    result = copy(annual)
    factors = present_value_factor(settings.DiscountRate, collect(settings.PeriodLengths))
    # Preserve numeric column types when no edges receive a credit.
    result[!, :period_payment] = Float64[r.annual_payment * settings.PeriodLengths[r.period] for r in eachrow(result)]
    result[!, :discounted_payment] = Float64[r.annual_payment * factors[r.period] *
        present_value_annuity_factor(settings.DiscountRate, settings.PeriodLengths[r.period]) for r in eachrow(result)]
    write_dataframe(path, result)
    return result
end

write_flow_credits(path::AbstractString, system::System, settings::NamedTuple, scaling::Float64) =
    write_flow_credits(path, get_flow_credits(system, scaling), settings)

# Use declared units, including a declared parent commodity. Unknown units remain
# missing rather than assigning MWh to every built-in or custom commodity.
function flow_credit_unit(commodity::Type{<:Commodity})
    while commodity <: Commodity
        declared = get(DEFAULT_UNITS, typesymbol(commodity), nothing)
        isnothing(declared) || return string(declared)
        commodity = supertype(commodity)
    end
    return missing
end
