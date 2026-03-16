struct CO2Injection <: AbstractAsset
    id::AssetId
    co2injection_transform::Transformation
    co2_captured_edge::Edge{<:CO2Captured}
    co2_storage_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{CO2Injection}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{CO2Injection}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "CO2Captured",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
            )
        ),
        :edges => Dict{Symbol,Any}(
            :co2_captured_edge => @edge_data(
                :co2_source => missing,
                :commodity => "CO2Captured",
                :has_capacity => true,
                :can_expand => false,
                :can_retire => false,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
            ),
            :co2_storage_edge => @edge_data(
                :co2_storage => missing,
                :commodity => "CO2Captured",
            )
        )
    )
end

function simple_default_data(::Type{CO2Injection}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => false,
        :can_retire => false,
        :existing_capacity => 0.0,
        :co2_source => missing,
        :co2_storage => missing,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )

end

function make(asset_type::Type{CO2Injection}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    co2injection_key = :transforms
    @process_data(
        transform_data,
        data[co2injection_key],
        [
            (data[co2injection_key], key),
            (data[co2injection_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    co2injection_transform = Transformation(;
        id = Symbol(id, "_", co2injection_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = transform_data[:constraints],
    )

    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data,
        data[:edges][co2_captured_edge_key],
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
            (data, key),
        ]
    )
    @start_vertex(
        co2_captured_start_node,
        co2_captured_edge_data,
        CO2Captured,
        [(co2_captured_edge_data, :start_vertex), (data, :co2_source), (data, :location)]
    )
    co2_captured_end_node = co2injection_transform
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )

    co2_storage_edge_key = :co2_storage_edge
    @process_data(
        co2_storage_edge_data,
        data[:edges][co2_storage_edge_key],
        [
            (data[:edges][co2_storage_edge_key], key),
            (data[:edges][co2_storage_edge_key], Symbol("co2_storage_", key)),
            (data, Symbol("co2_storage_", key)),
        ]
    )
    co2_storage_start_node = co2injection_transform
    @end_vertex(
        co2_storage_end_node,
        co2_storage_edge_data,
        CO2Captured,
        [(co2_storage_edge_data, :end_vertex), (data, :co2_storage), (data, :location),],
    )
    co2_storage_edge = Edge(
        Symbol(id, "_", co2_storage_edge_key),
        co2_storage_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_storage_start_node,
        co2_storage_end_node,
    )

    co2injection_transform.balance_data = Dict(
        :co2_injection_to_storage => Dict(
            co2_captured_edge.id => 1.0,
            co2_storage_edge.id => 1.0
        )
    )

    return CO2Injection(id, co2injection_transform, co2_captured_edge, co2_storage_edge) 
end
