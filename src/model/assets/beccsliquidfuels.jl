struct BECCSLiquidFuels <: AbstractAsset
    id::AssetId
    beccs_transform::Transformation
    biomass_edge::Edge{Biomass}
    gasoline_edge::Edge{LiquidFuels}
    jetfuel_edge::Edge{LiquidFuels}
    diesel_edge::Edge{LiquidFuels}
    elec_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
    co2_emission_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end

function make(::Type{BECCSLiquidFuels}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    beccs_transform_key = :transforms
    transform_data = process_data(data[beccs_transform_key])
    beccs_transform = Transformation(;
        id = Symbol(id, "_", beccs_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    biomass_edge_key = :biomass_edge
    biomass_edge_data = process_data(data[:edges][biomass_edge_key])
    biomass_start_node = find_node(system.locations, Symbol(biomass_edge_data[:start_vertex]))
    biomass_end_node = beccs_transform
    biomass_edge = Edge(
        Symbol(id, "_", biomass_edge_key),
        biomass_edge_data,
        system.time_data[:Biomass],
        Biomass,
        biomass_start_node,
        biomass_end_node,
    )
    biomass_edge.constraints = get(biomass_edge_data, :constraints, [CapacityConstraint()])
    biomass_edge.unidirectional = get(biomass_edge_data, :unidirectional, true)

    gasoline_edge_key = :gasoline_edge
    gasoline_edge_data = process_data(data[:edges][gasoline_edge_key])
    gasoline_start_node = beccs_transform
    gasoline_end_node = find_node(system.locations, Symbol(gasoline_edge_data[:end_vertex]))
    gasoline_edge = Edge(
        Symbol(id, "_", gasoline_edge_key),
        gasoline_edge_data,
        system.time_data[:LiquidFuels],
        LiquidFuels,
        gasoline_start_node,
        gasoline_end_node,
    )
    gasoline_edge.constraints = Vector{AbstractTypeConstraint}()
    gasoline_edge.unidirectional = true;
    gasoline_edge.has_capacity = false;

    jetfuel_edge_key = :jetfuel_edge
    jetfuel_edge_data = process_data(data[:edges][jetfuel_edge_key])
    jetfuel_start_node = beccs_transform
    jetfuel_end_node = find_node(system.locations, Symbol(jetfuel_edge_data[:end_vertex]))
    jetfuel_edge = Edge(
        Symbol(id, "_", jetfuel_edge_key),
        jetfuel_edge_data,
        system.time_data[:LiquidFuels],
        LiquidFuels,
        jetfuel_start_node,
        jetfuel_end_node,
    )
    jetfuel_edge.constraints = Vector{AbstractTypeConstraint}()
    jetfuel_edge.unidirectional = true;
    jetfuel_edge.has_capacity = false;

    diesel_edge_key = :diesel_edge
    diesel_edge_data = process_data(data[:edges][diesel_edge_key])
    diesel_start_node = beccs_transform
    diesel_end_node = find_node(system.locations, Symbol(diesel_edge_data[:end_vertex]))
    diesel_edge = Edge(
        Symbol(id, "_", diesel_edge_key),
        diesel_edge_data,
        system.time_data[:LiquidFuels],
        LiquidFuels,
        diesel_start_node,
        diesel_end_node,
    )
    diesel_edge.constraints = Vector{AbstractTypeConstraint}()
    diesel_edge.unidirectional = true;
    diesel_edge.has_capacity = false;

    elec_edge_key = :elec_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_end_node = beccs_transform
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = Vector{AbstractTypeConstraint}()
    elec_edge.unidirectional = true;
    elec_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = find_node(system.locations, Symbol(co2_edge_data[:start_vertex]))
    co2_end_node = beccs_transform
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
    co2_edge.has_capacity = false;

    co2_emission_edge_key = :co2_emission_edge
    co2_emission_edge_data = process_data(data[:edges][co2_emission_edge_key])
    co2_emission_start_node = beccs_transform
    co2_emission_end_node = find_node(system.locations, Symbol(co2_emission_edge_data[:end_vertex]))
    co2_emission_edge = Edge(
        Symbol(id, "_", co2_emission_edge_key),
        co2_emission_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_emission_start_node,
        co2_emission_end_node,
    )
    co2_emission_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_emission_edge.unidirectional = true;
    co2_emission_edge.has_capacity = false;

    co2_captured_edge_key = :co2_captured_edge
    co2_captured_edge_data = process_data(data[:edges][co2_captured_edge_key])
    co2_captured_start_node = beccs_transform
    co2_captured_end_node = find_node(system.locations, Symbol(co2_captured_edge_data[:end_vertex]))
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_captured_edge.unidirectional = true;
    co2_captured_edge.has_capacity = false;

    beccs_transform.balance_data = Dict(
        :gasoline_production => Dict(
            gasoline_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :gasoline_production, 0.0)
        ),
        :jetfuel_production => Dict(
            jetfuel_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :jetfuel_production, 0.0)
        ),
        :diesel_production => Dict(
            diesel_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :diesel_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_edge.id => -1.0,
            biomass_edge.id => get(transform_data, :electricity_consumption, 0.0)
        ),
        :negative_emissions => Dict(
            biomass_edge.id => get(transform_data, :co2_content, 0.0),
            co2_edge.id => -1.0
        ),
        :emissions => Dict(
            biomass_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture =>Dict(
            biomass_edge.id => get(transform_data, :capture_rate, 1.0),
            co2_captured_edge.id => 1.0
        )
    )

    return BECCSLiquidFuels(id, beccs_transform, biomass_edge,gasoline_edge,jetfuel_edge,diesel_edge,elec_edge,co2_edge,co2_emission_edge,co2_captured_edge) 
end
