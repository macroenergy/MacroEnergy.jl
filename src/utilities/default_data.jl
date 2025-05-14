function edge_default_data()
    return Dict{Symbol,Any}(
        :id => missing,
        :commodity => missing,
        :timedata => missing,
        :constraints => Dict{Symbol,Bool}(),
        :start_vertex => missing,
        :end_vertex => missing,
        :location => missing,
        :unidirectional => true,
        :availability => missing,
        :has_capacity => false,
        :can_expand => false,
        :can_retire => false,
        :capacity_size => 1.0,
        :existing_capacity => 0.0,
        :min_capacity => 0.0,
        :max_capacity => Inf,
        :max_new_capacity => Inf,
        :integer_decisions => false,
        :loss_fraction => 0.0,
        :efficiency => 1.0,
        :min_flow_fraction => 0.0,
        :ramp_up_fraction => 1.0,
        :ramp_down_fraction => 1.0,
        :distance => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :uc => false,
        :min_down_time => 0.0,
        :min_up_time => 0.0,
        :startup_cost => 0.0,
        :startup_fuel => 0.0,
        :startup_fuel_consumption => 0.0,
        :startup_fuel_balance_id => :none,
        :lifetime => 1,
        :capital_recovery_period => 1,
        :wacc => 0.0,
        :retirement_period => 0,
        :annualized_investment_cost => 0.0
    )
end

function transform_default_data()
    return Dict{Symbol, Any}(
        :id => missing,
        :timedata => missing,
        :location => missing,
        :constraints => Dict{Symbol,Bool}(),
    )
end

function storage_default_data()
    return Dict{Symbol,Any}(
        :id => missing,
        :timedata => missing,
        :location => missing,
        :constraints => Dict{Symbol,Bool}(),
        :commodity => missing,
        :charge_edge => missing,
        :discharge_edge => missing,
        :charge_discharge_ratio => 1.0,
        :spillage_edge => missing,
        :long_duration => false,
        :can_expand => true,
        :can_retire => true,
        :capacity_size => 1.0,
        :existing_capacity => 0.0,
        :min_capacity => 0.0,
        :max_capacity => Inf,
        :max_new_capacity => Inf,
        :min_duration => 0.0,
        :max_duration => 0.0,
        :min_storage_level => 0.0,
        :max_storage_level => 0.0,
        :min_outflow_fraction => 0.0,
        :loss_fraction => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :capital_recovery_period => 1,
        :lifetime => 1,
        :wacc => 0.0,
        :retirement_period =>0,
        :annualized_investment_cost => missing
    )
end

function node_default_data()
    return Dict{Symbol, Any}(
        :id => missing,
        :timedata => missing,
        :location => missing,
        :constraints => Dict{Symbol,Bool}(),
        :demand => Float64[],
        :max_nsd => [0.0],
        :min_nsd => [0.0],
        :price => Float64[],
        :price_nsd => [0.0],
        :price_supply => [0.0],
        :max_supply => [0.0],
        :price_unmet_policy => Dict{Symbol,Any}(),
        :rhs_policy => Dict{Symbol,Any}(),
    )
end

macro edge_data(non_defaults...)
    return esc(quote
        merge!(edge_default_data(), Dict([$(non_defaults...)]))
    end)
end

macro transform_data(non_defaults...)
    return esc(quote
        merge!(transform_default_data(), Dict([$(non_defaults...)]))
    end)
end

macro storage_data(non_defaults...)
    return esc(quote
        merge!(storage_default_data(), Dict([$(non_defaults...)]))
    end)
end

macro node_data(non_defaults...)
    return esc(quote
        merge!(node_default_data(), Dict([$(non_defaults...)]))
    end)
end