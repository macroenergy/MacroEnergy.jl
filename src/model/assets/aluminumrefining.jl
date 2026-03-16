# AluminumRefining represents a facility that transforms electricity and aluminum scrap into refined aluminum
# It inherits from AbstractAsset and contains edges for electricity input, aluminum scrap input, and aluminum output
struct AluminumRefining <: AbstractAsset
    id::AssetId                                    # Unique identifier for the asset
    aluminum_transform::Transformation             # Transformation process that converts inputs to outputs
    elec_edge::Edge{<:Electricity}                  # Edge representing electricity input
    aluminumscrap_edge::Edge{<:AluminumScrap}       # Edge representing aluminum scrap input
    aluminum_edge::Edge{<:Aluminum}                 # Edge representing aluminum output
end

# Factory function to create default data for AluminumRefining
# style can be either "full" (detailed configuration) or "simple" (basic configuration)
function default_data(t::Type{AluminumRefining}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

# Creates detailed default configuration for AluminumRefining
# Includes transformation rates, constraints, and edge configurations
function full_default_data(::Type{AluminumRefining}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Aluminum",
            :elec_aluminum_rate => 0.0,
            :aluminumscrap_aluminum_rate => 0.0,
            :aluminum_emissions_rate => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            # Electricity input edge configuration
            :elec_edge => @edge_data(
                :commodity => "Electricity"
            ),
            # Aluminum output edge configuration
            :aluminum_edge => @edge_data(
                :commodity=>"Aluminum",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :capacity_size => 1,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                )
            ),
            # Aluminum scrap input edge configuration
            :aluminumscrap_edge => @edge_data(
                :commodity => "AluminumScrap"
            ),
        ),
    )
end

# Creates simplified default configuration for AluminumRefining
# Contains basic parameters without detailed edge configurations
function simple_default_data(::Type{AluminumRefining}, id=missing)
    return Dict{Symbol, Any}(
        :id => id,
        :location => missing,
        :can_expand => true,                      # Asset can be expanded
        :can_retire => true,                     # Asset can be retired
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :timedata => "Aluminum",
        :elec_aluminum_rate => 0.0,
        :aluminumscrap_aluminum_rate => 0.0,
        :aluminum_emissions_rate => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

# Main constructor function that creates an AluminumRefining asset from configuration data
function make(asset_type::Type{AluminumRefining}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    # Create the transformation process that converts inputs to outputs
    aluminumrefining_key = :transforms
    @process_data(
        transform_data,
        data[aluminumrefining_key],
        [
            (data[aluminumrefining_key], key),
            (data[aluminumrefining_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    aluminumrefining_transform = Transformation(;
        id = Symbol(id, "_", aluminumrefining_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    # Create the electricity input edge
    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data, 
        data[:edges][elec_edge_key], 
        [
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
            (data, Symbol("elec_", key))
        ]
    )

    # Set up electricity edge vertices (start and end nodes)
    @start_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = aluminumrefining_transform

    # Create the electricity edge
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    # Create the aluminum scrap input edge
    aluminumscrap_edge_key = :aluminumscrap_edge
    @process_data(
        aluminumscrap_edge_data, 
        data[:edges][aluminumscrap_edge_key], 
        [
            (data[:edges][aluminumscrap_edge_key], key),
            (data[:edges][aluminumscrap_edge_key], Symbol("aluminumscrap_", key)),
            (data, Symbol("aluminumscrap_", key))
        ]
    )

    # Set up aluminum scrap edge vertices
    @start_vertex(
        aluminumscrap_start_node,
        aluminumscrap_edge_data,
        AluminumScrap,
        [(aluminumscrap_edge_data, :start_vertex), (data, :location)],
    )
    aluminumscrap_end_node = aluminumrefining_transform

    # Create the aluminum scrap edge
    aluminumscrap_edge = Edge(
        Symbol(id, "_", aluminumscrap_edge_key),
        aluminumscrap_edge_data,
        system.time_data[:AluminumScrap],
        AluminumScrap,
        aluminumscrap_start_node,
        aluminumscrap_end_node,
    )

    # Create the aluminum output edge
    aluminum_edge_key = :aluminum_edge
    @process_data(
        aluminum_edge_data, 
        data[:edges][aluminum_edge_key], 
        [
            (data[:edges][aluminum_edge_key], key),
            (data[:edges][aluminum_edge_key], Symbol("aluminum_", key)),
            (data, Symbol("aluminum_", key)),
            (data, key),
        ]
    )
    aluminum_start_node = aluminumrefining_transform
    @end_vertex(
        aluminum_end_node,
        aluminum_edge_data,
        Aluminum,
        [(aluminum_edge_data, :end_vertex), (data, :location)],
    )
    aluminum_edge = Edge(
        Symbol(id, "_", aluminum_edge_key),
        aluminum_edge_data,
        system.time_data[:Aluminum],
        Aluminum,
        aluminum_start_node,
        aluminum_end_node,
    )

    # Set up balance constraints for the transformation process
    # These define how inputs (electricity and aluminum scrap) are converted to outputs (aluminum)
    aluminumrefining_transform.balance_data = Dict(
        :elec_to_aluminum => Dict(
            elec_edge.id => 1.0,                  # Electricity input coefficient
            aluminumscrap_edge.id => 0.0,         # No direct conversion from electricity to aluminum scrap
            aluminum_edge.id => get(transform_data, :elec_aluminum_rate, 0.0)
        ),
        :aluminumscrap_to_aluminum => Dict(
            elec_edge.id => 0.0,
            aluminumscrap_edge.id => 1.0,
            aluminum_edge.id => get(transform_data, :aluminumscrap_aluminum_rate, 0.0)
        )
    )
    return AluminumRefining(id, aluminumrefining_transform, elec_edge, aluminumscrap_edge, aluminum_edge)
end