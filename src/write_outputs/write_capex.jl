"""
CAPEX outputs — upfront investment cost × new capacity for each component that can have capacity variables and be expanded (edges and storages). """

"""
    write_capex(file_path::AbstractString, system::System, scaling::Float64, discount_rate::Float64; drop_cols::Vector{<:AbstractString}=String[])

Write CAPEX results (upfront investment cost × new capacity) for all expandable
edges and storages in the system to a file.

CAPEX is defined as `investment_cost × new_capacity`. When only
`annualized_investment_cost` is provided (i.e. `investment_cost == 0`), the
upfront cost is back-calculated as:

```
investment_cost = annualized_investment_cost / capital_recovery_factor(wacc, capital_recovery_period)
```

When `wacc` is missing on a component, `discount_rate` is used as the fallback —
consistent with the forward computation in `compute_annualized_costs!`.

No discounting is applied.

# Arguments
- `file_path::AbstractString`: Path to the output file (extension determines format)
- `system::System`: The system containing the assets to analyze
- `scaling::Float64`: Parameter scaling factor; applied as `scaling^2` since CAPEX is a product of a cost and a capacity (each scaled by `scaling`)
- `discount_rate::Float64`: Fallback rate when a component's `wacc` is missing (should match `settings.DiscountRate`)
- `drop_cols::Vector{AbstractString}`: Columns to drop from the DataFrame

# Returns
- `nothing`
"""
function write_capex(
    file_path::AbstractString,
    system::System,
    scaling::Float64=1.0,
    discount_rate::Float64=0.0;
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing CAPEX results to $file_path"
    capex_results = get_capex(system, scaling, discount_rate)
    write_dataframe(file_path, capex_results, drop_cols)
    return nothing
end

"""
    get_capex(system::System, scaling::Float64, discount_rate::Float64) -> DataFrame

Compute CAPEX (`investment_cost × new_capacity`) for all expandable edges and
storages in the system. Returns a DataFrame with one row per component.

`discount_rate` is used as the fallback `wacc` when a component's `wacc` is missing.
"""
function get_capex(system::System, scaling::Float64=1.0, discount_rate::Float64=0.0)
    edges, edge_asset_map = edges_with_capacity_variables(system, return_ids_map=true)
    storages, storage_asset_map = storages_with_capacity_variables(system, return_ids_map=true)
    all_objs = vcat(edges, storages)
    all_maps = merge(edge_asset_map, storage_asset_map)

    isempty(all_objs) && return DataFrame()

    rows = [
        (
            commodity      = get_commodity_name(obj),
            zone           = get_zone_name(obj),
            resource_id    = get_resource_id(obj, all_maps),
            component_id   = get_component_id(obj),
            resource_type  = get_type(all_maps[id(obj)]),
            component_type = get_type(obj),
            variable       = :capex,
            value          = _capex_value(obj, discount_rate) * scaling^2
        )
        for obj in all_objs
    ]

    df = DataFrame(rows)
    df[!, (!isa).(eachcol(df), Vector{Missing})]
end

# Return the CAPEX value (investment_cost × new_capacity) for a component.
# If investment_cost == 0 but annualized_investment_cost is set, back-calculate
# the upfront cost from the annualized cost and the capital recovery factor.
# discount_rate is the fallback when wacc is missing, matching compute_annualized_costs!.
function _capex_value(obj::Union{AbstractEdge, AbstractStorage}, discount_rate::Float64=0.0)
    (has_capacity(obj) && can_expand(obj)) || return 0.0

    inv_cost = investment_cost(obj)
    if inv_cost == 0.0
        ann_inv_cost = annualized_investment_cost(obj)
        (isnothing(ann_inv_cost) || ann_inv_cost == 0.0) && return 0.0
        w = ismissing(wacc(obj)) ? discount_rate : wacc(obj)
        inv_cost = ann_inv_cost / capital_recovery_factor(w, capital_recovery_period(obj))
    end

    return inv_cost * Float64(value(new_capacity(obj)))
end
