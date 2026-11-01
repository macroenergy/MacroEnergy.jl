"""Annual weighted PTC payment in model units; positive for government payments."""
function compute_ptc_payment(e::AbstractEdge)::Float64
    iszero(ptc_rate(e)) && return 0.0
    return ptc_rate(e) * sum(subperiod_weight(e, current_subperiod(e, t)) * value(flow(e, t)) for t in time_interval(e))
end

function empty_ptc_payments()
    return DataFrame(period=Int[], resource_id=String[], edge_id=String[],
        zone=String[], type=String[], tags=String[], ptc_rate=Float64[],
        eligible_generation_mwh=Float64[], annual_payment=Float64[])
end

"""Extract annual payments in original units, preserving each resource and edge."""
function get_ptc_payments(system::System, scaling::Float64)
    result = empty_ptc_payments()
    edges, asset_map = get_edges(system, return_ids_map=true)
    tags = Dict(id(a) => format_asset_tags(a) for a in system.assets)
    for e in edges
        iszero(ptc_rate(e)) && continue
        asset = asset_map[id(e)]
        asset = asset isa Ref ? asset[] : asset
        generation = sum(subperiod_weight(e, current_subperiod(e, t)) * value(flow(e, t)) for t in time_interval(e))
        push!(result, (period_index(e), string(id(asset)), string(id(e)), get_zone_name(e),
            get_type(asset), get(tags, id(asset), ""), ptc_rate(e) * scaling,
            generation * scaling, ptc_rate(e) * generation * scaling^2))
    end
    return result
end

"""Aggregate subperiods while retaining resource/vintage and edge identity."""
function aggregate_ptc_payments(frames::Vector{DataFrame})
    nonempty = filter(!isempty, frames)
    isempty(nonempty) && return empty_ptc_payments()
    data = reduce(vcat, nonempty)
    keys = [:period, :resource_id, :edge_id, :zone, :type, :tags, :ptc_rate]
    return combine(groupby(data, keys),
        :eligible_generation_mwh => sum => :eligible_generation_mwh,
        :annual_payment => sum => :annual_payment)
end

function write_ptc_payments(path::AbstractString, annual::DataFrame, settings::NamedTuple)
    result = copy(annual)
    factors = present_value_factor(settings.DiscountRate, collect(settings.PeriodLengths))
    result[!, :period_payment] = [r.annual_payment * settings.PeriodLengths[r.period] for r in eachrow(result)]
    result[!, :discounted_payment] = [r.annual_payment * factors[r.period] *
        present_value_annuity_factor(settings.DiscountRate, settings.PeriodLengths[r.period]) for r in eachrow(result)]
    CSV.write(path, result)
    return result
end

write_ptc_payments(path::AbstractString, system::System, settings::NamedTuple, scaling::Float64) =
    write_ptc_payments(path, get_ptc_payments(system, scaling), settings)
