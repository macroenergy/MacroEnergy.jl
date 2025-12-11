struct DirectReductionElectricArcFurnaceCCS <: AbstractAsset
    id::AssetId
    dreafccs_transform::Transformation
    crudesteel_edge::Edge{CrudeSteel}
    reductant_edge::Edge{NaturalGas}
    elec_edge::Edge{Electricity}
    ironore_edge::Edge{<:IronOre}
    co2_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}

end

function default_data(t::Type{DirectReductionElectricArcFurnaceCCS}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{DirectReductionElectricArcFurnaceCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "CrudeSteel",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :ironore_consumption => 0.0,
            :electricity_consumption => 0.0,
            :reductant_consumption => 0.0,
            :emission_rate => 0.0
        ),
        :edges => Dict{Symbol,Any}(
            :crudesteel_edge => @edge_data(
                :commodity => "CrudeSteel",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :reductant_edge => @edge_data(
                :commodity => "NaturalGas"
            ),
            :ironore_edge => @edge_data(
                :commodity => "IronOre"
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :co2_edge => @edge_data(
                :commodity => "CO2"
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured"
            )
        ),
    )
end


function simple_default_data(::Type{DirectReductionElectricArcFurnaceCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :ironore_consumption => 0.0,
        :electricity_consumption => 0.0,
        :reductant_consumption => 0.0,
        :emission_rate => 0.0
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function set_commodity!(::Type{DirectReductionElectricArcFurnaceCCS}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    edge_keys = [:reductant_edge]
    if haskey(data, :reductant_commodity)
        data[:reductant_commodity] = string(commodity)
    end
    if haskey(data, :edges)
        for edge_key in edge_keys
            if haskey(data[:edges], edge_key)
                if haskey(data[:edges][edge_key], :commodity)
                    data[:edges][edge_key][:commodity] = string(commodity)
                end
            end
        end
    end
end

function make(asset_type::Type{DirectReductionElectricArcFurnaceCCS}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    @setup_data(asset_type, data, id)

    dreafccs_key = :transforms 
    transform_data = process_data(data[dreafccs_key])
    dreafccs_transform = Transformation(;
        id = Symbol(id, "_", dreafccs_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    # iron ore edge
    ironore_edge_key = :ironore_edge
    @process_data(
        ironore_edge_data, 
        data[:edges][ironore_edge_key], 
        [
            (data[:edges][ironore_edge_key], key),
            (data[:edges][ironore_edge_key], Symbol("ironore_", key)),
            (data, Symbol("ironore_", key)),
        ]
    )
    commodity_symbol = Symbol(ironore_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        ironore_start_node,
        ironore_edge_data,
        commodity,
        [(ironore_edge_data, :start_vertex), (data, :location)],
    )

    ironore_end_node = dreafccs_transform
    ironore_edge = Edge(
        Symbol(id, "_", ironore_edge_key),
        ironore_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ironore_start_node,
        ironore_end_node,
    )
    ironore_edge.unidirectional = get(ironore_edge_data, :unidirectional, true)

    # electricity edge
    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data, 
        data[:edges][elec_edge_key], 
        [
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
            (data, Symbol("elec_", key)),
        ]
    )
    @end_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = dreafccs_transform 
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.unidirectional = true

    # reductant edge 

    reductant_edge_key = :reductant_edge
    @process_data(
        reductant_edge_data, 
        data[:edges][reductant_edge_key], 
        [
            (data[:edges][reductant_edge_key], key),
            (data[:edges][reductant_edge_key], Symbol("reductant_", key)),
            (data, Symbol("reductant_", key)),
        ]
    )

    @start_vertex(
        reductant_start_node,
        reductant_edge_data,
        NaturalGas,
        [(reductant_edge_data, :start_vertex), (data, :location)],
    )
    reductant_end_node = dreafccs_transform
    reductant_edge = Edge(
        Symbol(id, "_", reductant_edge_key),
        reductant_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        reductant_start_node,
        reductant_end_node,
    )
    reductant_edge.unidirectional = true;

    # co2 edge
    co2_edge_key = :co2_edge
    @process_data(
        co2_edge_data, 
        data[:edges][co2_edge_key], 
        [
            (data[:edges][co2_edge_key], key),
            (data[:edges][co2_edge_key], Symbol("co2_", key)),
            (data, Symbol("co2_", key)),
        ]
    )
    co2_start_node = dreafccs_transform
    @end_vertex(
        co2_end_node,
        co2_edge_data,
        CO2,
        [(co2_edge_data, :end_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    co2_edge.unidirectional = true;

    # CO2 captured edge
    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data, 
        data[:edges][co2_captured_edge_key], 
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
        ]
    )
    co2_captured_start_node = dreafccs_transform
    @end_vertex(
        co2_captured_end_node,
        co2_captured_edge_data,
        CO2Captured,
        [(co2_captured_edge_data, :end_vertex), (data, :location)],
    )    
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )

    # crude steel edge
    crudesteel_edge_key = :crudesteel_edge
    @process_data(
        crudesteel_edge_data,
        data[:edges][crudesteel_edge_key],
        [
            (data[:edges][crudesteel_edge_key], key),
            (data[:edges][crudesteel_edge_key], Symbol("crudesteel_", key)),
            (data, Symbol("crudesteel_", key)),
        ]
    )
    crudesteel_start_node = dreafccs_transform
    @end_vertex(
        crudesteel_end_node,
        crudesteel_edge_data,
        CrudeSteel,
        [(crudesteel_edge_data, :end_vertex), (data, :location)],
    )
    crudesteel_edge = Edge(
        Symbol(id, "_", crudesteel_edge_key),
        crudesteel_edge_data,
        system.time_data[:CrudeSteel],
        CrudeSteel,
        crudesteel_start_node,
        crudesteel_end_node,

    )

    crudesteel_edge.constraints = get(
        crudesteel_edge_data,
        :constraints,
        [
            CapacityConstraint()
        ]
    )
    crudesteel_edge.unidirectional = get(crudesteel_edge_data, :unidirectional, true)

    dreafccs_transform.balance_data = Dict(
        :ironore_consumption=> Dict(
            crudesteel_edge.id => get(transform_data, :ironore_consumption, 0.0),
            ironore_edge.id => 1.0
        ),
        :electricity_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :electricity_consumption, 0.0),
            elec_edge.id => 1.0
        ),
        :reductant_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :reductant_consumption, 0.0),
            reductant_edge.id => 1.0
        ),
        :emissions => Dict(
            crudesteel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => -1.0,
        ),
        :capture => Dict(
            crudesteel_edge.id => get(transform_data, :capture_rate, 0.0),
            co2_captured_edge.id => -1.0,
        )
    )

    return DirectReductionElectricArcFurnaceCCS(id,
            dreafccs_transform,
            crudesteel_edge,
            reductant_edge,
            elec_edge,
            ironore_edge,
            co2_edge,
            co2_captured_edge)
end
