struct BlastFurnaceBasicOxygenFurnaceCCS <: AbstractAsset
    id::AssetId
    bfbofccs_transform::Transformation
    ironore_edge::Edge{<:IronOre}
    metcoal_edge::Edge{<:Coal}
    thermalcoal_edge::Edge{<:Coal}
    steelscrap_edge::Edge{SteelScrap}
    natgas_edge::Edge{NaturalGas} 
    crudesteel_edge::Edge{CrudeSteel}
    elec_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end

function default_data(t::Type{BlastFurnaceBasicOxygenFurnaceCCS}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{BlastFurnaceBasicOxygenFurnaceCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "CrudeSteel",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :ironore_consumption => 0.0,
            :electricity_consumption => 0.0,
            :metcoal_consumption => 0.0,
            :thermalcoal_consumption => 0.0,
            :natgas_consumption => 0.0,
            :steelscrap_consumption => 0.0,
            :emission_rate => 0.0,
            :capture_rate => 0.0
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
            :metcoal_edge => @edge_data(
                :commodity => "Coal"
            ),
            :thermalcoal_edge => @edge_data(
                :commodity => "Coal"
            ),
            :ironore_edge => @edge_data(
                :commodity => "IronOre"
            ),
            :steelscrap_edge => @edge_data(
                :commodity => "SteelScrap"
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity"
            ),
            :natgas_edge => @edge_data(
                :commodity => "NaturalGas"
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

function simple_default_data(::Type{BlastFurnaceBasicOxygenFurnaceCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :ironore_consumption => 0.0,
        :electricity_consumption => 0.0,
        :metcoal_consumption => 0.0,
        :thermalcoal_consumption => 0.0,
        :natgas_consumption => 0.0,
        :steelscrap_consumption => 0.0,
        :emission_rate => 0.0,
        :capture_rate => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end


function make(asset_type::Type{BlastFurnaceBasicOxygenFurnaceCCS}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    bfbofccs_key = :transforms 
    @process_data(
        transform_data, 
        data[bfbofccs_key], 
        [
            (data[bfbofccs_key], key),
            (data[bfbofccs_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    bfbofccs_transform = Transformation(;
        id = Symbol(id, "_", bfbofccs_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
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

    ironore_end_node = bfbofccs_transform
    ironore_edge = Edge(
        Symbol(id, "_", ironore_edge_key),
        ironore_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ironore_start_node,
        ironore_end_node,
    )
    ironore_edge.unidirectional = true

    # steel scrap edge

    steelscrap_edge_key = :steelscrap_edge
    @process_data(
        steelscrap_edge_data, 
        data[:edges][steelscrap_edge_key], 
        [
            (data[:edges][steelscrap_edge_key], key),
            (data[:edges][steelscrap_edge_key], Symbol("steelscrap_", key)),
            (data, Symbol("steelscrap_", key)),
        ]
    )
    @start_vertex(
        steelscrap_start_node,
        steelscrap_edge_data,
        SteelScrap,
        [(steelscrap_edge_data, :start_vertex), (data, :location)],
    )

    steelscrap_end_node = bfbofccs_transform
    steelscrap_edge = Edge(
        Symbol(id, "_", steelscrap_edge_key),
        steelscrap_edge_data,
        system.time_data[:SteelScrap],
        SteelScrap,
        steelscrap_start_node,
        steelscrap_end_node,
    )
    steelscrap_edge.unidirectional = true

    # metalurgical coal edge

    metcoal_edge_key = :metcoal_edge
    @process_data(
        metcoal_edge_data, 
        data[:edges][metcoal_edge_key], 
        [
            (data[:edges][metcoal_edge_key], key),
            (data[:edges][metcoal_edge_key], Symbol("metcoal_", key)),
            (data, Symbol("metcoal_", key)),
        ]
    )
    commodity_symbol = Symbol(metcoal_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        metcoal_start_node,
        metcoal_edge_data,
        commodity,
        [(metcoal_edge_data, :start_vertex), (data, :location)],
    )
    metcoal_end_node = bfbofccs_transform
    metcoal_edge = Edge(
        Symbol(id, "_", metcoal_edge_key),
        metcoal_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        metcoal_start_node,
        metcoal_end_node,
    )
    metcoal_edge.unidirectional = true;

    # thermal coal edge

    thermalcoal_edge_key = :thermalcoal_edge
    @process_data(
        thermalcoal_edge_data, 
        data[:edges][thermalcoal_edge_key], 
        [
            (data[:edges][thermalcoal_edge_key], key),
            (data[:edges][thermalcoal_edge_key], Symbol("thermalcoal_", key)),
            (data, Symbol("thermalcoal_", key)),
        ]
    )
    commodity_symbol = Symbol(thermalcoal_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        thermalcoal_start_node,
        thermalcoal_edge_data,
        commodity,
        [(thermalcoal_edge_data, :start_vertex), (data, :location)],
    )
    thermalcoal_end_node = bfbofccs_transform

    thermalcoal_edge = Edge(
        Symbol(id, "_", thermalcoal_edge_key),
        thermalcoal_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        thermalcoal_start_node,
        thermalcoal_end_node,
    )
    thermalcoal_edge.unidirectional = true;

    # natural gas edge

    natgas_edge_key = :natgas_edge
    @process_data(
        natgas_edge_data,
        data[:edges][natgas_edge_key],
        [
            (data[:edges][natgas_edge_key], key),
            (data[:edges][natgas_edge_key], Symbol("natgas_", key)),
            (data, Symbol("natgas_", key)),
        ]
    )
    @start_vertex(
        natgas_start_node,
        natgas_edge_data,
        NaturalGas,
        [(natgas_edge_data, :start_vertex), (data, :location)],
    )
    natgas_end_node = bfbofccs_transform

    natgas_edge = Edge(
        Symbol(id, "_", natgas_edge_key),
        natgas_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_start_node,
        natgas_end_node,
    )
    natgas_edge.unidirectional = true;

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
    @start_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = bfbofccs_transform 
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.unidirectional = true

    # CO2 edge

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
    co2_start_node = bfbofccs_transform
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
    co2_edge.constraints = Vector{AbstractTypeConstraint}()
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
    co2_captured_start_node = bfbofccs_transform
    @end_vertex(
        co2_captured_end_node,
        co2_captured_edge_data,
        CO2Captured,
        [(co2_captured_edge_data, :end_vertex), (data, :co2_sink), (data, :location)],
    )    
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.unidirectional = true;

    # crude steel edge
    crudesteel_edge_key = :crudesteel_edge
    @process_data(
        crudesteel_edge_data, 
        data[:edges][crudesteel_edge_key], 
        [
            (data[:edges][crudesteel_edge_key], key),
            (data[:edges][crudesteel_edge_key], Symbol("crudesteel_", key)),
            (data, Symbol("crudesteel_", key)),
            (data, key),
        ]
    )
    crudesteel_start_node = bfbofccs_transform
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
        [MustRunConstraint()])
    crudesteel_edge.unidirectional = true
    
    # stochiometry
    bfbofccs_transform.balance_data = Dict(
        :ironore_consumption=> Dict(
            crudesteel_edge.id => get(transform_data, :ironore_consumption, 0.0),
            ironore_edge.id => 1.0
        ),
        :steelscrap_consumption=> Dict(
            crudesteel_edge.id => get(transform_data, :steelscrap_consumption, 0.0),
            steelscrap_edge.id => 1.0
        ),
        :electricity_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :electricity_consumption, 0.0),
            elec_edge.id => 1.0
        ),
        :metcoal_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :metcoal_consumption, 0.0),
            metcoal_edge.id => 1.0
        ),
        :thermalcoal_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :thermalcoal_consumption, 0.0),
            thermalcoal_edge.id => 1.0
        ),
        :natgas_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :natgas_consumption, 0.0),
            natgas_edge.id => 1.0
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

    return BlastFurnaceBasicOxygenFurnaceCCS(id,
            bfbofccs_transform,
            ironore_edge,
            metcoal_edge,
            thermalcoal_edge,
            steelscrap_edge,
            natgas_edge,
            crudesteel_edge,
            elec_edge,
            co2_edge,
            co2_captured_edge
        )
end
