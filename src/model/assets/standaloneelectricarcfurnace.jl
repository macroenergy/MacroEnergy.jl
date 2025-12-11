struct ElectricArcFurnace{T <: Commodity} <: AbstractAsset
    id::AssetId
    eaf_transform::Transformation
    crudesteel_edge::Edge{CrudeSteel}
    elec_edge::Edge{Electricity}
    steelscrap_edge::Edge{SteelScrap} 
    naturalgas_edge::Edge{NaturalGas}
    carbonsource_edge::Edge{T}
    co2_edge::Edge{CO2}
end


function default_data(t::Type{ElectricArcFurnace}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ElectricArcFurnace}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :electricity_consumption => 0.0,
            :steelscrap_consumption => 0.0,
            :naturalgas_consumption => 0.0,
            :carbonsource_consumption => 0.0,
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
            :steelscrap_edge => @edge_data(
                :commodity => "SteelScrap"
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity"
            ),
            :naturalgas_edge => @edge_data(
                :commodity => "NaturalGas"
            ),
            :carbonsource_edge => @edge_data(
                :commodity => missing
            ),
            :co2_edge => @edge_data(
                :commodity => "CO2"
            )
        ),
    )
end


function simple_default_data(::Type{ElectricArcFurnace}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :electricity_consumption => 0.0,
        :steelscrap_consumption => 0.0,
        :naturalgas_consumption => 0.0,
        :carbonsource_consumption => 0.0,
        :emission_rate => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function set_commodity!(::Type{ElectricArcFurnace}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    edge_keys = [:carbonsource_edge]
    if haskey(data, :carbonsource_commodity)
        data[:carbonsource_commodity] = string(commodity)
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

function make(asset_type::Type{ElectricArcFurnace}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    @setup_data(asset_type, data, id)

    eaf_key = :transforms
    transform_data = process_data(data[eaf_key])
    eaf_transform = Transformation(;
        id = Symbol(id, "_", eaf_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )
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
    elec_end_node = eaf_transform 
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.unidirectional = true

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
    steelscrap_end_node = eaf_transform
    steelscrap_edge = Edge(
        Symbol(id, "_", steelscrap_edge_key),
        steelscrap_edge_data,
        system.time_data[:SteelScrap],
        SteelScrap,
        steelscrap_start_node,
        steelscrap_end_node,
    )
    steelscrap_edge.unidirectional = true;

    # natural gas edge

    naturalgas_edge_key = :naturalgas_edge
    @process_data(
        naturalgas_edge_data,
        data[:edges][naturalgas_edge_key],
        [
            (data[:edges][naturalgas_edge_key], key),
            (data[:edges][naturalgas_edge_key], Symbol("naturalgas_", key)),
            (data, Symbol("naturalgas_", key)),
        ]
    )
    @start_vertex(
        naturalgas_start_node,
        naturalgas_edge_data,
        NaturalGas,
        [(naturalgas_edge_data, :start_vertex), (data, :location)],
    )
    naturalgas_end_node = eaf_transform

    naturalgas_edge = Edge(
        Symbol(id, "_", naturalgas_edge_key),
        naturalgas_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        naturalgas_start_node,
        naturalgas_end_node,
    )
    naturalgas_edge.unidirectional = true;

    # carbonsource edge

    carbonsource_edge_key = :carbonsource_edge
    @process_data(
        carbonsource_edge_data, 
        data[:edges][carbonsource_edge_key], 
        [
            (data[:edges][carbonsource_edge_key], key),
            (data[:edges][carbonsource_edge_key], Symbol("carbonsource_", key)),
            (data, Symbol("carbonsource_", key)),
        ]
    )
    commodity_symbol = Symbol(carbonsource_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        carbonsource_start_node,
        carbonsource_edge_data,
        commodity,
        [(carbonsource_edge_data, :start_vertex), (data, :location)],
    )
    carbonsource_end_node = eaf_transform
    carbonsource_edge = Edge(
        Symbol(id, "_", carbonsource_edge_key),
        carbonsource_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        carbonsource_start_node,
        carbonsource_end_node,
    )
    carbonsource_edge.unidirectional = true;

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
    crudesteel_start_node = eaf_transform
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
    crudesteel_edge.unidirectional = get(crudesteel_edge_data, :unidirectional, true)

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
    co2_start_node = eaf_transform
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

    # stochiometry
    eaf_transform.balance_data = Dict(
        :electricity_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :electricity_consumption, 0.0),
            elec_edge.id => 1.0,
        ),
        :steelscrap_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :steelscrap_consumption, 0.0),
            steelscrap_edge.id => 1.0
        ),
        :naturalgas_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :naturalgas_consumption, 0.0),
            naturalgas_edge.id => 1.0,
        ),
        :carbonsource_consumption => Dict(
            crudesteel_edge.id => get(transform_data, :carbonsource_consumption, 0.0),
            carbonsource_edge.id => 1.0,
        ),
        :emissions => Dict(
            crudesteel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => -1.0,
        ) 
    )


    return ElectricArcFurnace(id,
            eaf_transform,
            crudesteel_edge,
            elec_edge,
            steelscrap_edge,
            naturalgas_edge,
            carbonsource_edge,
            co2_edge
        )
end
