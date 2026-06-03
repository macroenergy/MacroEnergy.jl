macro AbstractEdgeBaseAttributes()
    edge_defaults = edge_default_data()
    esc(quote
        id::Symbol
        location::Union{Missing, Symbol} = $edge_defaults[:location]
        timedata::TimeData{T}
        start_vertex::AbstractVertex
        end_vertex::AbstractVertex
        availability::Vector{Float64} = Float64[]
        can_expand::Bool = $edge_defaults[:can_expand]
        can_retire::Bool = $edge_defaults[:can_retire]
        can_retrofit::Bool = $edge_defaults[:can_retrofit]
        capacity::Union{JuMPVariable,AffExpr,Float64} = AffExpr(0.0)
        capacity_size::Float64 = $edge_defaults[:capacity_size]
        capital_recovery_period::Int64 = $edge_defaults[:capital_recovery_period]
        constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
        distance::Float64 = $edge_defaults[:distance]
        existing_capacity::Union{JuMPVariable,AffExpr,Float64,Int64} = $edge_defaults[:existing_capacity]
        fixed_om_cost::Float64 = $edge_defaults[:fixed_om_cost]
        flow::JuMPVariable = Vector{VariableRef}()
        has_capacity::Bool = $edge_defaults[:has_capacity]
        integer_decisions::Bool = $edge_defaults[:integer_decisions]
        investment_cost::Float64 = $edge_defaults[:investment_cost]
        is_retrofit::Bool = $edge_defaults[:is_retrofit]
        lifetime::Int64 = $edge_defaults[:lifetime]
        loss_fraction::Vector{Float64} = $edge_defaults[:loss_fraction]
        max_capacity::Float64 = $edge_defaults[:max_capacity]
        max_new_capacity::Float64 = $edge_defaults[:max_new_capacity]
        min_capacity::Float64 = $edge_defaults[:min_capacity]
        min_retired_capacity::Float64 = $edge_defaults[:min_retired_capacity]
        min_retired_capacity_track::Float64 = 0.0
        min_flow_fraction::Float64 = $edge_defaults[:min_flow_fraction]
        new_capacity::Union{AffExpr,Float64} = AffExpr(0.0)
        new_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        new_units::Union{JuMPVariable,Float64} = 0.0
        ramp_down_fraction::Float64 = $edge_defaults[:ramp_down_fraction]
        ramp_up_fraction::Float64 = $edge_defaults[:ramp_up_fraction]
        retired_capacity::Union{AffExpr,Float64} = AffExpr(0.0)
        retired_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        retired_units::Union{JuMPVariable,Float64} = 0.0
        retrofit_efficiency::Union{Missing,Float64} = $edge_defaults[:retrofit_efficiency]
        retrofit_id::Union{Missing, Vector{Symbol}} = $edge_defaults[:retrofit_id]
        retrofitted_capacity::AffExpr = AffExpr(0.0)
        retrofitted_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        retrofitted_units::Union{JuMPVariable,Float64} = 0.0
        variable_om_cost::Float64 = $edge_defaults[:variable_om_cost]
        min_down_time::Int64 = $edge_defaults[:min_down_time]
        min_up_time::Int64 = $edge_defaults[:min_up_time]
        startup_cost::Float64 = $edge_defaults[:startup_cost]
        startup_fuel_consumption::Float64 = $edge_defaults[:startup_fuel_consumption]
        startup_fuel_balance_id::Symbol = $edge_defaults[:startup_fuel_balance_id]
        retirement_period::Int64 = $edge_defaults[:retirement_period]
        wacc::Union{Missing,Float64} = missing
        annualized_investment_cost::Union{Nothing,Float64} = $edge_defaults[:annualized_investment_cost]
        pv_period_investment_cost::Union{Nothing,Float64} = $edge_defaults[:pv_period_investment_cost]
        cf_period_investment_cost::Union{Nothing,Float64} = $edge_defaults[:cf_period_investment_cost]
        pv_period_fixed_om_cost::Union{Nothing,Float64} = $edge_defaults[:pv_period_fixed_om_cost]
        cf_period_fixed_om_cost::Union{Nothing,Float64} = $edge_defaults[:cf_period_fixed_om_cost]
        pv_period_variable_om_cost::Union{Nothing,Float64} = $edge_defaults[:pv_period_variable_om_cost]
        cf_period_variable_om_cost::Union{Nothing,Float64} = $edge_defaults[:cf_period_variable_om_cost]
        # Learning
        learning_type::String = ""
        learning_parameter::Float64 = 0.0
        cumulative_capacity_init::Float64 = 0.0
        endogenous_capex_segment_chosen_track::Dict{Int64,Union{JuMPVariable}} = Dict(1 => Vector{VariableRef}())
        endogenous_capex_segment_chosen_from_relevant_period::Union{JuMPVariable,Float64} = Vector{VariableRef}()
        aux_new_capacity::Union{JuMPVariable,Float64} = 0.0
        cumulative_experience::Union{JuMPVariable,Float64} = 0.0
        endogenous_capex::AffExpr = AffExpr(0.0)
        endogenous_capex_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        pwl_capex_slopes::Vector{Float64} = Float64[]
        endog_annualized_investment_cost_times_newcapacity::AffExpr = AffExpr(0.0)
        annuities_mult::Float64 = 0.0
        annualization_factor::Float64 = 0.0
        endog_annualized_cost::AffExpr = AffExpr(0.0)
        init_cumul_capacity::Float64 = 0.0
        endog_annualized_investment_cost::AffExpr = 0.0
        max_cumul_capacity::Float64 = 0.0
        learning_delay::Int64 = 1
        interconnect_annuity::Float64 = 0.0
        interconnect_annuities_mult::Float64 = 0.0
        # Project development
        de_duration::Int64 = $edge_defaults[:de_duration]
        af_duration::Int64 = $edge_defaults[:af_duration]
        cc_duration::Int64 = $edge_defaults[:cc_duration]
        # Definition and evaluation (DE)
        de_cost_perc::Float64 = 0.0
        de_wacc::Float64 = 0.1
        de_annualization_factor::Float64 = 0.0
        de_cap_recovery::Int64 = 1
        de_annuities_mult::Float64 = 0.0
        de_annualized_cost::Float64 = 0.0
        new_de_capacity::AffExpr = AffExpr(0.0)
        new_de_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        de_capacity::Union{JuMPVariable,AffExpr,Float64} = AffExpr(0.0)
        de_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        new_de_units::Union{JuMPVariable,Float64} = 0.0
        endog_annualized_investment_cost_times_newcapacity_de::AffExpr = AffExpr(0.0)
        aux_new_capacity_de::Union{JuMPVariable,Float64} = 0.0
        # Approvals and funding (AF)
        af_cost_perc::Float64 = 0.0
        af_wacc::Float64 = 0.1
        af_annualization_factor::Float64 = 0.0
        af_cap_recovery::Int64 = 1
        af_annuities_mult::Float64 = 0.0
        af_annualized_cost::Float64 = 0.0
        new_af_capacity::AffExpr = AffExpr(0.0)
        new_af_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        af_capacity::Union{JuMPVariable,AffExpr,Float64} = AffExpr(0.0)
        af_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        new_af_units::Union{JuMPVariable,Float64} = 0.0
        endog_annualized_investment_cost_times_newcapacity_af::AffExpr = AffExpr(0.0)
        aux_new_capacity_af::Union{JuMPVariable,Float64} = 0.0
        # Construction and Commissioning (CC)
        cc_cost_perc::Float64 = 0.0
        cc_wacc::Float64 = 0.05
        cc_annualization_factor::Float64 = 0.0
        cc_cap_recovery::Int64 = 1
        cc_annuities_mult::Float64 = 0.0
        cc_annualized_cost::Float64 = 0.0
        new_cc_capacity::AffExpr = AffExpr(0.0)
        new_cc_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        cc_capacity::Union{JuMPVariable,AffExpr,Float64} = AffExpr(0.0)
        cc_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        new_cc_units::Union{JuMPVariable,Float64} = 0.0
        endog_annualized_investment_cost_times_newcapacity_cc::AffExpr = AffExpr(0.0)
        aux_new_capacity_cc::Union{JuMPVariable,Float64} = 0.0
        capacity_in_progress_init::Float64 = 0.0
        new_capital::Union{AffExpr,Float64} = AffExpr(0.0)
        new_capital_de::Union{AffExpr,Float64} = AffExpr(0.0)
        new_capital_af::Union{AffExpr,Float64} = AffExpr(0.0)
        new_capital_cc::Union{AffExpr,Float64} = AffExpr(0.0)
        itc_schedule::Vector{Float64} = zeros(20)
        # Max growth formulation
        max_new_capacity_init::Float64 = 0.0
        cagr::Float64 = 0.0
        cadr::Float64 = 0.0
        Inertia_category::Union{Nothing,String} = nothing
    end)
end

abstract type EdgeWithoutUC{T} <: AbstractEdge{T} end

"""
    UnidirectionalEdge{T} <: EdgeWithoutUC{T}

    A mutable struct representing an edge in a network model, parameterized by commodity type T.

    # Fields
    - id::Symbol: Unique identifier for the edge
    - timedata::TimeData: Time-related data for the edge
    - start_vertex::AbstractVertex: Starting vertex of the edge
    - end_vertex::AbstractVertex: Ending vertex of the edge
    - availability::Vector{Float64}: Time series of availability factors
    - can_expand::Bool: Whether edge capacity can be expanded
    - can_retire::Bool: Whether edge capacity can be retired
    - capacity::Union{AffExpr,Float64}: Total available capacity
    - capacity_size::Float64: Size factor for resource cluster
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the edge
    - distance::Float64: Physical distance of the edge
    - existing_capacity::Float64: Initial installed capacity
    - fixed_om_cost::Float64: Fixed operation and maintenance costs
    - flow::Union{JuMPVariable,Vector{Float64}}: Flow of commodity `T` through the edge at each timestep
    - has_capacity::Bool: Whether the edge has capacity variables
    - integer_decisions::Bool: Whether capacity decisions must be integer
    - investment_cost::Float64: CAPEX per unit of new capacity
    - loss_fraction::Vector{Float64}: Fraction of flow lost during transmission, it can be time-dependent.
    - max_capacity::Float64: Maximum allowed capacity
    - min_capacity::Float64: Minimum required capacity
    - min_retired_capacity::Float64: Minimum capacity that must be retired in this period
    - min_flow_fraction::Float64: Minimum flow as fraction of capacity
    - new_capacity::Union{JuMPVariable,Float64}: JuMP variable representing new capacity built
    - ramp_down_fraction::Float64: Maximum ramp-down rate as fraction of capacity
    - ramp_up_fraction::Float64: Maximum ramp-up rate as fraction of capacity
    - ret_capacity::Union{JuMPVariable,Float64}: JuMP variable representing capacity to be retired
    - variable_om_cost::Float64: Variable operation and maintenance costs per unit flow

    Edges represent connections between vertices that allow commodities to flow between them. 
    They can model physical infrastructure like pipelines, transmission lines, or logical 
    connections with associated costs, capacities, and operational constraints.
"""
Base.@kwdef mutable struct UnidirectionalEdge{T} <: EdgeWithoutUC{T}
    @AbstractEdgeBaseAttributes()
end

"""
    BidirectionalEdge{T} <: EdgeWithoutUC{T}

    A mutable struct representing an edge in a network model, parameterized by commodity type T.

    # Fields
    - id::Symbol: Unique identifier for the edge
    - timedata::TimeData: Time-related data for the edge
    - start_vertex::AbstractVertex: Starting vertex of the edge
    - end_vertex::AbstractVertex: Ending vertex of the edge
    - availability::Vector{Float64}: Time series of availability factors
    - can_expand::Bool: Whether edge capacity can be expanded
    - can_retire::Bool: Whether edge capacity can be retired
    - capacity::Union{AffExpr,Float64}: Total available capacity
    - capacity_size::Float64: Size factor for resource cluster
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the edge
    - distance::Float64: Physical distance of the edge
    - existing_capacity::Float64: Initial installed capacity
    - fixed_om_cost::Float64: Fixed operation and maintenance costs
    - flow::Union{JuMPVariable,Vector{Float64}}: Flow of commodity `T` through the edge at each timestep
    - has_capacity::Bool: Whether the edge has capacity variables
    - integer_decisions::Bool: Whether capacity decisions must be integer
    - investment_cost::Float64: CAPEX per unit of new capacity
    - loss_fraction::Vector{Float64}: Fraction of flow lost during transmission, it can be time-dependent.
    - max_capacity::Float64: Maximum allowed capacity
    - min_capacity::Float64: Minimum required capacity
    - min_retired_capacity::Float64: Minimum capacity that must be retired in this period
    - min_flow_fraction::Float64: Minimum flow as fraction of capacity
    - new_capacity::Union{JuMPVariable,Float64}: JuMP variable representing new capacity built
    - ramp_down_fraction::Float64: Maximum ramp-down rate as fraction of capacity
    - ramp_up_fraction::Float64: Maximum ramp-up rate as fraction of capacity
    - ret_capacity::Union{JuMPVariable,Float64}: JuMP variable representing capacity to be retired
    - variable_om_cost::Float64: Variable operation and maintenance costs per unit flow

    Edges represent connections between vertices that allow commodities to flow between them. 
    They can model physical infrastructure like pipelines, transmission lines, or logical 
    connections with associated costs, capacities, and operational constraints.
"""
Base.@kwdef mutable struct BidirectionalEdge{T} <: EdgeWithoutUC{T}
    @AbstractEdgeBaseAttributes()
end

const Edge = UnidirectionalEdge

commodity_type(::Type{AbstractEdge{T}}) where {T} = T
function commodity_type(t::Type{AbstractEdge{<:T}}) where {T}
    ub_type = t.var.ub
    return commodity_type(AbstractEdge{ub_type})
end
commodity_type(::Type{Edge{T}}) where {T} = T
function commodity_type(t::Type{Edge{<:T}}) where {T}
    ub_type = t.var.ub
    return commodity_type(Edge{ub_type})
end

function target_is_valid(commodity::Type{<:Commodity}, target::T) where T<:Union{Node, AbstractStorage}
    target_commodity = commodity_type(target)
    if (commodity === target_commodity) || (commodity <: target_commodity)
        return true
    end
    return false
end

function target_is_valid(commodity::Type{<:Commodity}, target)
    return true
end

function target_is_valid(edge::AbstractEdge, target::AbstractVertex)
    return target_is_valid(commodity_type(edge), target)
end

function make_edge_unidir(
    id::Symbol,
    data::AbstractDict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
)
    if !(target_is_valid(commodity, start_vertex))
        error("Edge $id cannot be connected to its start vertex, $(start_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(start_vertex.id) is a $(commodity_type(start_vertex)) vertex.")
    elseif !target_is_valid(commodity, end_vertex)
        error("Edge $id cannot be connected to its end vertex, $(end_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(end_vertex.id) is a $(commodity_type(end_vertex)) vertex.")
    end

    edge_kwargs = Base.fieldnames(Edge)
    filtered_data = Dict{Symbol, Any}(
        k => v for (k,v) in data if k in edge_kwargs
    )
    remove_keys = [:id, :start_vertex, :end_vertex, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    if haskey(filtered_data,:loss_fraction) && !isa(filtered_data[:loss_fraction], Vector{Float64})
        filtered_data[:loss_fraction] = [filtered_data[:loss_fraction]];
    end
    unidirectional = get(data, :unidirectional, true)
    if !unidirectional
        error("Edge $id is being created as a unidirectional edge, but the input data has unidirectional=false. If you intended to create a bidirectional edge, set unidirectional=false and use the BidirectionalEdge constructor.")
    end
    _edge = UnidirectionalEdge{commodity}(;
        id = id,
        timedata = time_data,
        start_vertex = start_vertex,
        end_vertex = end_vertex,
        filtered_data...
    )
    return _edge
end

Edge(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
) = make_edge_unidir(id, data, time_data, commodity, start_vertex, end_vertex)

function make_edge_bidir(
    id::Symbol,
    data::AbstractDict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
)
    if !(target_is_valid(commodity, start_vertex))
        error("Edge $id cannot be connected to its start vertex, $(start_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(start_vertex.id) is a $(commodity_type(start_vertex)) vertex.")
    elseif !target_is_valid(commodity, end_vertex)
        error("Edge $id cannot be connected to its end vertex, $(end_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(end_vertex.id) is a $(commodity_type(end_vertex)) vertex.")
    end

    edge_kwargs = Base.fieldnames(Edge)
    filtered_data = Dict{Symbol, Any}(
        k => v for (k,v) in data if k in edge_kwargs
    )
    remove_keys = [:id, :start_vertex, :end_vertex, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    if haskey(filtered_data,:loss_fraction) && !isa(filtered_data[:loss_fraction], Vector{Float64})
        filtered_data[:loss_fraction] = [filtered_data[:loss_fraction]];
    end
    unidirectional = get(data, :unidirectional, false)
    if unidirectional
        error("Edge $id is being created as a bidirectional edge, but the input data has unidirectional=true. If you intended to create a unidirectional edge, set unidirectional=true and use the Edge constructor directly.")
    end
    _edge = BidirectionalEdge{commodity}(;
        id = id,
        timedata = time_data,
        start_vertex = start_vertex,
        end_vertex = end_vertex,
        filtered_data...
    )
    return _edge
end

BidirectionalEdge(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
) = make_edge_bidir(id, data, time_data, commodity, start_vertex, end_vertex)

# Function to filter edges with capacity variables from a Vector of edges.
edges_with_capacity_variables(edges::Vector{<:AbstractEdge}) =
    AbstractEdge[edge for edge in edges if has_capacity(edge)]

######### Edge interface #########
all_constraints(e::AbstractEdge) = e.constraints;
all_constraints_types(e::AbstractEdge) = [typeof(c) for c in all_constraints(e)]
function get_constraint_by_type(e::AbstractEdge, constraint_type::Type{<:AbstractTypeConstraint})
    constraints = all_constraints(e)
    matches = filter(c -> typeof(c) == constraint_type, constraints)
    return length(matches) == 1 ? matches[1] : length(matches) > 1 ? matches : nothing
end
availability(e::AbstractEdge) = e.availability;
function availability(e::AbstractEdge, t::Int64)
    a = availability(e)
    if isempty(a)
        return 1.0
    elseif length(a) == 1
        return a[1]
    else
        return a[t]
    end
end
can_expand(e::AbstractEdge) = e.can_expand;
can_retire(e::AbstractEdge) = e.can_retire;
can_retrofit(e::AbstractEdge) = e.can_retrofit;
capacity(e::AbstractEdge) = e.capacity;
capacity_size(e::AbstractEdge) = e.capacity_size;
capital_recovery_period(e::AbstractEdge) = e.capital_recovery_period;
commodity_type(e::AbstractEdge{T}) where {T} = T;
end_vertex(e::AbstractEdge) = e.end_vertex;
existing_capacity(e::AbstractEdge) = e.existing_capacity;
fixed_om_cost(e::AbstractEdge) = e.fixed_om_cost;
flow(e::AbstractEdge) = e.flow;
flow(e::AbstractEdge, t::Int64) = flow(e)[t];
has_capacity(e::AbstractEdge) = e.has_capacity;
id(e::AbstractEdge) = e.id;
integer_decisions(e::AbstractEdge) = e.integer_decisions;
investment_cost(e::AbstractEdge) = e.investment_cost;
is_retrofit(e::AbstractEdge) = e.is_retrofit;
lifetime(e::AbstractEdge) = e.lifetime;
loss_fraction(e::AbstractEdge) = e.loss_fraction;
unidirectional(e::AbstractEdge) = true;
unidirectional(e::BidirectionalEdge) = false;
function loss_fraction(e::AbstractEdge, t::Int64)
    a = loss_fraction(e)
    if isempty(a)
        return 0.0
    elseif length(a) == 1
        return a[1]
    else
        return a[t]
    end
end
max_capacity(e::AbstractEdge) = e.max_capacity;
max_new_capacity(e::AbstractEdge) = e.max_new_capacity;
min_capacity(e::AbstractEdge) = e.min_capacity;
min_retired_capacity(e::AbstractEdge) = e.can_retire ? e.min_retired_capacity : 0.0;
min_retired_capacity_track(e::AbstractEdge) = e.min_retired_capacity_track;
min_flow_fraction(e::AbstractEdge) = e.min_flow_fraction;
new_capacity(e::AbstractEdge) = e.new_capacity;
new_capacity_track(e::AbstractEdge) = e.new_capacity_track;
#### Note that edge "e" may not be present in the inputs for all case
new_capacity_track(e::AbstractEdge,s::Int64) =  (haskey(new_capacity_track(e),s) == false) ? 0.0 : e.new_capacity_track[s];
new_units(e::AbstractEdge) = e.new_units;
ramp_down_fraction(e::AbstractEdge) = e.ramp_down_fraction;
ramp_up_fraction(e::AbstractEdge) = e.ramp_up_fraction;
retired_capacity(e::AbstractEdge) = e.retired_capacity;
retired_capacity_track(e::AbstractEdge) = e.retired_capacity_track;
#### Note that edge "e" may not be present in the inputs for all case
retired_capacity_track(e::AbstractEdge,s::Int64) =  (haskey(retired_capacity_track(e),s) == false) ? 0.0 : e.retired_capacity_track[s];
retired_units(e::AbstractEdge) = e.retired_units;
retirement_period(e::AbstractEdge) = e.retirement_period;
retrofit_efficiency(e::AbstractEdge) = e.retrofit_efficiency;
retrofit_id(e::AbstractEdge) = e.retrofit_id;
retrofitted_capacity(e::AbstractEdge) = e.retrofitted_capacity;
retrofitted_capacity_track(e::AbstractEdge) = e.retrofitted_capacity_track;
retrofitted_capacity_track(e::AbstractEdge,s::Int64) = (haskey(retrofitted_capacity_track(e),s) == false) ? 0.0 : e.retrofitted_capacity_track[s];
retrofitted_units(e::AbstractEdge) = e.retrofitted_units;
start_vertex(e::AbstractEdge)::AbstractVertex = e.start_vertex;
variable_om_cost(e::AbstractEdge) = e.variable_om_cost;
wacc(e::AbstractEdge) = e.wacc;
annualized_investment_cost(e::AbstractEdge) = e.annualized_investment_cost;
pv_period_investment_cost(e::AbstractEdge) = e.pv_period_investment_cost;
cf_period_investment_cost(e::AbstractEdge) = e.cf_period_investment_cost;
pv_period_fixed_om_cost(e::AbstractEdge) = e.pv_period_fixed_om_cost;
cf_period_fixed_om_cost(e::AbstractEdge) = e.cf_period_fixed_om_cost;
pv_period_variable_om_cost(e::AbstractEdge) = e.pv_period_variable_om_cost;
# Learning
learning_type(e::AbstractEdge) = e.learning_type;
n_learning_pwl_segments(e::AbstractEdge) = e.n_learning_pwl_segments;
learning_parameter(e::AbstractEdge) = e.learning_parameter;
cumulative_capacity_init(e::AbstractEdge) = e.cumulative_capacity_init;
endog_annualized_investment_cost(e::AbstractEdge) = e.endog_annualized_investment_cost;
endogenous_capex_segment_chosen_from_relevant_period(e::AbstractEdge) = e.endogenous_capex_segment_chosen_from_relevant_period;
cumulative_experience(e::AbstractEdge) = e.cumulative_experience;
endogenous_capex(e::AbstractEdge) = e.endogenous_capex;
endogenous_capex_track(e::AbstractEdge) = e.endogenous_capex_track;
endogenous_capex_track(e::AbstractEdge, s::Int64) = (haskey(endogenous_capex_track(e), s) == false) ? 0.0 : e.endogenous_capex_track[s];
endogenous_capex_segment_chosen_track(e::AbstractEdge) = e.endogenous_capex_segment_chosen_track;
endogenous_capex_segment_chosen_track(e::AbstractEdge, s::Int64) = (haskey(endogenous_capex_segment_chosen_track(e), s) == false) ? 0.0 : e.endogenous_capex_segment_chosen_track[s];
pwl_capex_slopes(e::AbstractEdge) = e.pwl_capex_slopes;
aux_new_capacity(e::AbstractEdge) = e.aux_new_capacity;
endog_annualized_investment_cost_times_newcapacity(e::AbstractEdge) = e.endog_annualized_investment_cost_times_newcapacity;
annuities_mult(e::AbstractEdge) = e.annuities_mult;
annualization_factor(e::AbstractEdge) = e.annualization_factor;
endog_annualized_cost(e::AbstractEdge) = e.endog_annualized_cost;
init_cumul_capacity(e::AbstractEdge) = e.init_cumul_capacity;
max_cumul_capacity(e::AbstractEdge) = e.max_cumul_capacity;
learning_delay(e::AbstractEdge) = e.learning_delay;
interconnect_annuity(e::AbstractEdge) = e.interconnect_annuity;        
interconnect_annuities_mult(e::AbstractEdge) = e.interconnect_annuities_mult;
# Project development
de_duration(e::AbstractEdge) = e.de_duration;
af_duration(e::AbstractEdge) = e.af_duration;
cc_duration(e::AbstractEdge) = e.cc_duration;
de_cost_perc(e::AbstractEdge) = e.de_cost_perc;
af_cost_perc(e::AbstractEdge) = e.af_cost_perc;
cc_cost_perc(e::AbstractEdge) = e.cc_cost_perc;
de_wacc(e::AbstractEdge) = e.de_wacc;
af_wacc(e::AbstractEdge) = e.af_wacc;
cc_wacc(e::AbstractEdge) = e.cc_wacc;
de_annualization_factor(e::AbstractEdge) = e.de_annualization_factor;
af_annualization_factor(e::AbstractEdge) = e.af_annualization_factor;
cc_annualization_factor(e::AbstractEdge) = e.cc_annualization_factor;
de_cap_recovery(e::AbstractEdge) = e.de_cap_recovery;
af_cap_recovery(e::AbstractEdge) = e.af_cap_recovery;
cc_cap_recovery(e::AbstractEdge) = e.cc_cap_recovery;
de_annualized_cost(e::AbstractEdge) = e.de_annualized_cost;
af_annualized_cost(e::AbstractEdge) = e.af_annualized_cost;
cc_annualized_cost(e::AbstractEdge) = e.cc_annualized_cost;
de_annuities_mult(e::AbstractEdge) = e.de_annuities_mult;
af_annuities_mult(e::AbstractEdge) = e.af_annuities_mult;
cc_annuities_mult(e::AbstractEdge) = e.cc_annuities_mult;
# Definition and evaluation (DE)
new_de_capacity(e::AbstractEdge) = e.new_de_capacity;
de_capacity(e::AbstractEdge) = e.de_capacity;
new_de_capacity_track(e::AbstractEdge) = e.new_de_capacity_track;
new_de_capacity_track(e::AbstractEdge, s::Int64) = (haskey(new_de_capacity_track(e), s) == false) ? 0.0 : e.new_de_capacity_track[s];
de_capacity_track(e::AbstractEdge) = e.de_capacity_track;
de_capacity_track(e::AbstractEdge, s::Int64) = (haskey(de_capacity_track(e), s) == false) ? 0.0 : e.de_capacity_track[s];
new_de_units(e::AbstractEdge) = e.new_de_units;
aux_new_capacity_de(e::AbstractEdge) = e.aux_new_capacity_de;
endog_annualized_investment_cost_times_newcapacity_de(e::AbstractEdge) = e.endog_annualized_investment_cost_times_newcapacity_de;
# Approvals and funding (AF)
new_af_capacity(e::AbstractEdge) = e.new_af_capacity;
af_capacity(e::AbstractEdge) = e.af_capacity;
new_af_capacity_track(e::AbstractEdge) = e.new_af_capacity_track;
new_af_capacity_track(e::AbstractEdge, s::Int64) = (haskey(new_af_capacity_track(e), s) == false) ? 0.0 : e.new_af_capacity_track[s];
af_capacity_track(e::AbstractEdge) = e.af_capacity_track;
af_capacity_track(e::AbstractEdge, s::Int64) = (haskey(af_capacity_track(e), s) == false) ? 0.0 : e.af_capacity_track[s];
new_af_units(e::AbstractEdge) = e.new_af_units;
aux_new_capacity_af(e::AbstractEdge) = e.aux_new_capacity_af;
endog_annualized_investment_cost_times_newcapacity_af(e::AbstractEdge) = e.endog_annualized_investment_cost_times_newcapacity_af;
# Construction and commissioning (CC)
new_cc_capacity(e::AbstractEdge) = e.new_cc_capacity;
cc_capacity(e::AbstractEdge) = e.cc_capacity;
new_cc_capacity_track(e::AbstractEdge) = e.new_cc_capacity_track;
new_cc_capacity_track(e::AbstractEdge, s::Int64) = (haskey(new_cc_capacity_track(e), s) == false) ? 0.0 : e.new_cc_capacity_track[s];
cc_capacity_track(e::AbstractEdge) = e.cc_capacity_track;
cc_capacity_track(e::AbstractEdge, s::Int64) = (haskey(cc_capacity_track(e), s) == false) ? 0.0 : e.cc_capacity_track[s];
new_cc_units(e::AbstractEdge) = e.new_cc_units;
aux_new_capacity_cc(e::AbstractEdge) = e.aux_new_capacity_cc;
endog_annualized_investment_cost_times_newcapacity_cc(e::AbstractEdge) = e.endog_annualized_investment_cost_times_newcapacity_cc;
capacity_in_progress_init(e::AbstractEdge) = e.capacity_in_progress_init;
new_capital(e::AbstractEdge) = e.new_capital;
new_capital_de(e::AbstractEdge) = e.new_capital_de;
new_capital_af(e::AbstractEdge) = e.new_capital_af;
new_capital_cc(e::AbstractEdge) = e.new_capital_cc;
itc_schedule(e::AbstractEdge) = e.itc_schedule;
# Max growth formulation
max_new_capacity_init(e::AbstractEdge) = e.max_new_capacity_init;
cagr(e::AbstractEdge) = e.cagr;
cadr(e::AbstractEdge) = e.cadr;
Inertia_category(e::AbstractEdge) = e.Inertia_category;
##### End of Edge interface #####

function add_linking_variables!(e::AbstractEdge, model::Model)

    if has_capacity(e)
        e.capacity = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(id(e))_period$(period_index(e))")
    end

    return nothing

end

function define_available_capacity!(e::AbstractEdge, model::Model)

    if has_capacity(e)
        
        e.new_units = @variable(model, lower_bound = 0.0, base_name = "vNEWUNIT_$(id(e))_period$(period_index(e))")

        e.retired_units = @variable(model, lower_bound = 0.0, base_name = "vRETUNIT_$(id(e))_period$(period_index(e))")

        e.new_capacity = @expression(model, capacity_size(e) * new_units(e))
        
        e.retired_capacity = @expression(model, capacity_size(e) * retired_units(e))

        e.new_capacity_track[period_index(e)] = new_capacity(e);
        
        e.retired_capacity_track[period_index(e)] = retired_capacity(e);

        if can_retrofit(e)

            e.retrofitted_units = @variable(model, lower_bound = 0.0, base_name = "vRETROFITUNIT_$(id(e))_period$(period_index(e))")
            
            e.retrofitted_capacity = @expression(model, capacity_size(e) * retrofitted_units(e))

            e.retrofitted_capacity_track[period_index(e)] = retrofitted_capacity(e)

            @constraint(model, capacity(e) == new_capacity(e) - retired_capacity(e) - retrofitted_capacity(e) + existing_capacity(e))
            
        else
            @constraint(model, capacity(e) == new_capacity(e) - retired_capacity(e) + existing_capacity(e))
        end

        # Project development
        # Definition and evaluation (DE)
        e.new_de_units = @variable(model, lower_bound = 0.0, base_name = "vNEWDEUNIT_$(id(e))_stage$(period_index(e))")
        e.new_de_capacity = @expression(model, capacity_size(e) * new_de_units(e))
        e.new_de_capacity_track[period_index(e)] = new_de_capacity(e)
        e.de_capacity = @variable(model, lower_bound = 0.0, base_name = "vDECAP_$(id(e))_stage$(period_index(e))")
        e.de_capacity_track[period_index(e)] = de_capacity(e)
        # Approvals and funding (AF)
        e.new_af_units = @variable(model, lower_bound = 0.0, base_name = "vNEWAFUNIT_$(id(e))_stage$(period_index(e))")
        e.new_af_capacity = @expression(model, capacity_size(e) * new_af_units(e))
        e.new_af_capacity_track[period_index(e)] = new_af_capacity(e)
        e.af_capacity = @variable(model, lower_bound = 0.0, base_name = "vAFCAP_$(id(e))_stage$(period_index(e))")
        e.af_capacity_track[period_index(e)] = af_capacity(e)
        # Construction and commissioning (CC)
        e.new_cc_units = @variable(model, lower_bound = 0.0, base_name = "vNEWCCUNIT_$(id(e))_stage$(period_index(e))")
        e.new_cc_capacity = @expression(model, capacity_size(e) * new_cc_units(e))
        e.new_cc_capacity_track[period_index(e)] = new_cc_capacity(e)
        e.cc_capacity = @variable(model, lower_bound = 0.0, base_name = "vCCCAP_$(id(e))_stage$(period_index(e))")
        e.cc_capacity_track[period_index(e)] = cc_capacity(e)
    end

    return nothing

end

function planning_model!(e::AbstractEdge, model::Model, settings::NamedTuple)

    if has_capacity(e)

        if !can_expand(e)
            fix(new_units(e), 0.0; force = true)
            # Project development
            fix(new_de_units(e), 0.0; force=true)
            fix(new_af_units(e), 0.0; force=true)
            fix(new_cc_units(e), 0.0; force=true)
            fix(de_capacity(e), 0.0; force=true)
            fix(af_capacity(e), 0.0; force=true)
            fix(cc_capacity(e), 0.0; force=true)
        else
            if integer_decisions(e)
                set_integer(new_units(e))
            end
        end

        if !can_retire(e)
            fix(retired_units(e), 0.0; force = true)
        else
            if integer_decisions(e)
                set_integer(retired_units(e))
            end
        end

        if can_retrofit(e)
            @constraint(model, retrofitted_capacity(e) + retired_capacity(e) <= existing_capacity(e))
            if integer_decisions(e)
                set_integer(retrofitted_units(e))
            end
        else
            @constraint(model, retired_capacity(e) <= existing_capacity(e))
        end

        # Deployment Inertia speed limit constraints
        if settings[:DeploymentInertia] && !isnothing(Inertia_category(e)) && Inertia_category(e) ∈ settings[:TechsWithInertia]
            if period_index(e) == 1
                add_to_expression!(model[:eDeploymentGrowth][Inertia_category(e), period_index(e)], new_capacity(e))
                add_to_expression!(model[:eDeploymentDecline][Inertia_category(e), period_index(e)], new_capacity(e))
            elseif period_index(e) > 1
                # CAGR
                model[:eDeploymentGrowth][Inertia_category(e), period_index(e)] += new_capacity(e) - new_capacity_track(e, period_index(e)-1)*(1+cagr(e))
                # CADR
                model[:eDeploymentDecline][Inertia_category(e), period_index(e)] += new_capacity(e) - new_capacity_track(e, period_index(e)-1)*(1-cadr(e))
            end
        end

    end

    compute_fixed_costs!(e, model, settings, :PV)

    return nothing

end

function compute_investment_costs!(e::AbstractEdge, model::Model, settings::NamedTuple, cost_type::Function=pv_period_investment_cost)
    if has_capacity(e)
        if can_expand(e)

            # Apply subsidy depending on stage
            de_itc_schedule = [e.itc_schedule[(e.de_duration+e.af_duration)+1:end]; zeros(min((e.de_duration+e.af_duration), length(e.itc_schedule)))]
            af_itc_schedule = [e.itc_schedule[(e.af_duration)+1:end]; zeros(min((e.af_duration), length(e.itc_schedule)))]

            if cost_type == pv_period_investment_cost
                # Costs used by model
                if settings[:TechnologyLearning] && learning_type(e) in settings[:LearningTechnologies]
                    # Linearized learning
                    model[:eInvestmentFixedCost] += e.endog_annualized_investment_cost_times_newcapacity * annuities_mult(e) + interconnect_annuity(e) * interconnect_annuities_mult(e) * new_capacity(e)
                    # Nonlinear version for benchmarking
                    # model[:eInvestmentFixedCost] += (1 - subsidy)*endog_annualized_investment_cost(e)*annuities_mult(e)*new_capacity(e)

                    # Shadow capacity for project development constraints (project development)
                    model[:eInvestmentFixedCost] +=
                        e.endog_annualized_investment_cost_times_newcapacity_de * (1 - de_itc_schedule[period_index(e)]) * de_annuities_mult(e)
                    model[:eInvestmentFixedCost] +=
                        e.endog_annualized_investment_cost_times_newcapacity_af * (1 - af_itc_schedule[period_index(e)]) * af_annuities_mult(e)
                    model[:eInvestmentFixedCost] +=
                        e.endog_annualized_investment_cost_times_newcapacity_cc * (1 - e.itc_schedule[period_index(e)]) * cc_annuities_mult(e)

                elseif !settings[:TechnologyLearning] || !(learning_type(e) in settings[:LearningTechnologies])
                    # Technologies without endogenous learning
                    add_to_expression!(
                        model[:eInvestmentFixedCost],
                        annualized_investment_cost(e) * annuities_mult(e),
                        new_capacity(e),
                    )

                    # Capacity for project development constraints (project development)
                    add_to_expression!(
                        model[:eInvestmentFixedCost],
                        de_annualized_cost(e) * (1 - de_itc_schedule[period_index(e)]) * de_annuities_mult(e),
                        new_de_capacity(e),
                    )
                    add_to_expression!(
                        model[:eInvestmentFixedCost],
                        af_annualized_cost(e) * (1 - af_itc_schedule[period_index(e)]) * af_annuities_mult(e),
                        new_af_capacity(e),
                    )
                    add_to_expression!(
                        model[:eInvestmentFixedCost],
                        cc_annualized_cost(e) * (1 - e.itc_schedule[period_index(e)]) * cc_annuities_mult(e),
                        new_cc_capacity(e),
                    )

                end

                if settings[:ProjectDevelopment]
                e.new_capital = @expression(model, investment_cost(e) * (1 - de_cost_perc(e) - af_cost_perc(e) - cc_cost_perc(e)) * new_capacity(e) * (1 - e.itc_schedule[period_index(e)]))
            else
                e.new_capital = @expression(model, investment_cost(e) * new_capacity(e) * (1 - e.itc_schedule[period_index(e)]))
            end

            e.new_capital_de = @expression(model, investment_cost(e) * de_cost_perc(e) * new_de_capacity(e) * (1 - de_itc_schedule[period_index(e)]))
            e.new_capital_af = @expression(model, investment_cost(e) * af_cost_perc(e) * new_af_capacity(e) * (1 - af_itc_schedule[period_index(e)]))
            e.new_capital_cc = @expression(model, investment_cost(e) * cc_cost_perc(e) * new_cc_capacity(e) * (1 - e.itc_schedule[period_index(e)]))

            else
                # Cash flow costs for output writing
                add_to_expression!(
                    model[:eInvestmentFixedCost],
                    cost_type(e),
                    new_capacity(e),
                )
            end
            
        end
    end
end

function compute_om_fixed_costs!(e::AbstractEdge, model::Model, cost_type::Function=pv_period_fixed_om_cost)
    if has_capacity(e)
        if fixed_om_cost(e) > 0
            add_to_expression!(
                model[:eOMFixedCost],
                cost_type(e),
                capacity(e),
            )
        end
    end
end

function compute_fixed_costs!(e::AbstractEdge, model::Model, settings::NamedTuple, cost_type::Symbol=:PV)
    allowed_cost_types = [:PV, :CF]
    if !(cost_type in allowed_cost_types)
        error("Invalid cost type: $cost_type. Allowed types are: $(allowed_cost_types)")
    end
    invesment_cost_function = Dict{Symbol, Function}(
        :PV => pv_period_investment_cost,
        :CF => cf_period_investment_cost
    )
    fom_cost_function = Dict{Symbol, Function}(
        :PV => pv_period_fixed_om_cost,
        :CF => cf_period_fixed_om_cost
    )
    compute_investment_costs!(e, model, settings, invesment_cost_function[cost_type])
    compute_om_fixed_costs!(e, model, fom_cost_function[cost_type])
end

function add_operation_model_varcosts!(e::EdgeWithoutUC, model::Model)
    for t in time_interval(e)
        w = current_subperiod(e,t)
        vom_cost = variable_om_cost(e)
        if vom_cost > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * vom_cost,
                flow(e, t),
            )
        end
    end
end

function operation_model!(e::UnidirectionalEdge, model::Model)
    e.flow = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(id(e))_period$(period_index(e))"
    )
    update_balances!(e, model)
    add_operation_model_varcosts!(e, model)
    return nothing
end

function operation_model!(e::BidirectionalEdge, model::Model)
    e.flow = @variable(model, [t in time_interval(e)], base_name = "vFLOW_$(id(e))_period$(period_index(e))")
    update_balances!(e, model)
    add_operation_model_varcosts!(e, model)
    return nothing
end

"""
    EdgeWithUC{T} <: AbstractEdge{T}

    A mutable struct representing an edge with unit commitment constraints in a network model, parameterized by commodity type T.

    # Inherited Attributes from Edge
    - id::Symbol: Unique identifier for the edge
    - timedata::TimeData: Time-related data for the edge
    - start_vertex::AbstractVertex: Starting vertex of the edge
    - end_vertex::AbstractVertex: Ending vertex of the edge
    - availability::Vector{Float64}: Time series of availability factors
    - can_expand::Bool: Whether edge capacity can be expanded
    - can_retire::Bool: Whether edge capacity can be retired
    - capacity::Union{AffExpr,Float64}: Total available capacity
    - capacity_size::Float64: Size factor for resource cluster
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the edge
    - distance::Float64: Physical distance of the edge
    - existing_capacity::Float64: Initial installed capacity
    - fixed_om_cost::Float64: Fixed operation and maintenance costs
    - flow::Union{JuMPVariable,Vector{Float64}}: Flow of commodity through the edge at each timestep
    - has_capacity::Bool: Whether the edge has capacity variables
    - integer_decisions::Bool: Whether capacity decisions must be integer
    - investment_cost::Float64: CAPEX per unit of new capacity
    - loss_fraction::Float64: Fraction of flow lost during transmission
    - max_capacity::Float64: Maximum allowed capacity
    - min_capacity::Float64: Minimum required capacity
    - min_flow_fraction::Float64: Minimum flow as fraction of capacity
    - new_capacity::Union{JuMPVariable,Float64}: JuMP variable representing new capacity built
    - ramp_down_fraction::Float64: Maximum ramp-down rate as fraction of capacity
    - ramp_up_fraction::Float64: Maximum ramp-up rate as fraction of capacity
    - ret_capacity::Union{JuMPVariable,Float64}: JuMP variable representing capacity to be retired
    - variable_om_cost::Float64: Variable operation and maintenance costs per unit flow

    # Fields specific to EdgeWithUC
    - min_down_time::Int64: Minimum time units that must elapse between shutting down and starting up
    - min_up_time::Int64: Minimum time units that must elapse between starting up and shutting down
    - startup_cost::Float64: Cost incurred when starting up the unit
    - startup_fuel::Float64: Amount of fuel consumed during startup
    - startup_fuel_balance_id::Symbol: Identifier for the balance constraint tracking startup fuel
    - ucommit::Union{JuMPVariable,Vector{Float64}}: Binary commitment state variables
    - ushut::Union{JuMPVariable,Vector{Float64}}: Binary shutdown decision variables
    - ustart::Union{JuMPVariable,Vector{Float64}}: Binary startup decision variables

    EdgeWithUC extends Edge to model units that have operational constraints related to their on/off status. It includes variables and parameters
    for tracking unit commitment decisions and associated costs/constraints.
"""
Base.@kwdef mutable struct EdgeWithUC{T} <: AbstractEdge{T}
    @AbstractEdgeBaseAttributes()
    ucommit::JuMPVariable = Vector{VariableRef}()
    ushut::JuMPVariable = Vector{VariableRef}()
    ustart::JuMPVariable = Vector{VariableRef}()
end

commodity_type(::Type{EdgeWithUC{T}}) where {T} = T

function make_edge_UC(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
)

    if !(target_is_valid(commodity, start_vertex))
        error("Edge $id cannot be connected to its start vertex, $(start_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(start_vertex.id) is a $(commodity_type(start_vertex)) vertex.")
    elseif !target_is_valid(commodity, end_vertex)
        error("Edge $id cannot be connected to its end vertex, $(end_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(end_vertex.id) is a $(commodity_type(end_vertex)) vertex.")
    end

    edge_kwargs = Base.fieldnames(EdgeWithUC)
    filtered_data = Dict{Symbol,Any}(
        k => v for (k, v) in data if k in edge_kwargs
    )
    remove_keys = [:id, :start_vertex, :end_vertex, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    unidirectional = get(data, :unidirectional, true)
    if !unidirectional
        error("Edge $id is being created as a unidirectional edge, but the input data has unidirectional=false. Edges with Unit Commitment must be unidirectional.")
    end
    _edge = EdgeWithUC{commodity}(;
        id = id,
        timedata = time_data,
        start_vertex = start_vertex,
        end_vertex = end_vertex,
        filtered_data...,
    )
    return _edge
end
EdgeWithUC(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
) = make_edge_UC(id, data, time_data, commodity, start_vertex, end_vertex)

######### EdgeWithUC interface #########
min_down_time(e::EdgeWithUC) = e.min_down_time;
min_up_time(e::EdgeWithUC) = e.min_up_time;
startup_cost(e::EdgeWithUC) = e.startup_cost;
startup_fuel_consumption(e::EdgeWithUC) = e.startup_fuel_consumption;
startup_fuel_balance_id(e::EdgeWithUC) = e.startup_fuel_balance_id;
ucommit(e::EdgeWithUC) = e.ucommit;
ucommit(e::EdgeWithUC, t::Int64) = ucommit(e)[t];
ushut(e::EdgeWithUC) = e.ushut;
ushut(e::EdgeWithUC, t::Int64) = ushut(e)[t];
ustart(e::EdgeWithUC) = e.ustart;
ustart(e::EdgeWithUC, t::Int64) = ustart(e)[t];
##### End of EdgeWithUC interface #####

function add_operation_model_varcosts!(e::EdgeWithUC, model::Model)
    for t in time_interval(e)

        w = current_subperiod(e,t)
        vom_cost = variable_om_cost(e)
        if vom_cost > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * vom_cost,
                flow(e, t),
            )
        end

        if startup_cost(e) > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * startup_cost(e) * capacity_size(e),
                ustart(e, t),
            )
        end

    end
end

function operation_model!(e::EdgeWithUC, model::Model)
    if !has_capacity(e)
        error(
            "UC is available only for edges with capacity, set has_capacity to True for edge $(id(e))",
        )
        return nothing
    end

    e.flow = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(id(e))_period$(period_index(e))"
    )

    e.ucommit = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vCOMMIT_$(id(e))_period$(period_index(e))"
    )

    e.ustart = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSTART_$(id(e))_period$(period_index(e))"
    )

    e.ushut = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSHUT_$(id(e))_period$(period_index(e))"
    )

    update_balances!(e, model)
    update_startup_fuel_balance!(e)
    add_operation_model_varcosts!(e, model)

    ### DEFAULT CONSTRAINTS ###

    @constraints(
        model,
        begin
            [t in time_interval(e)], ucommit(e, t) <= capacity(e) / capacity_size(e)
            [t in time_interval(e)], ustart(e, t) <= capacity(e) / capacity_size(e)
            [t in time_interval(e)], ushut(e, t) <= capacity(e) / capacity_size(e)
        end
    )

    @constraint(
        model,
        [t in time_interval(e)],
        ucommit(e, t) - ucommit(e, timestepbefore(t, 1, subperiods(e))) ==
        ustart(e, t) - ushut(e, t)
    )

    return nothing
end

function edges(assets::Vector{AbstractAsset})
    edges = Vector{AbstractEdge}()
    for a in assets
        for f in fieldnames(typeof(a))
            if isa(getfield(a, f), AbstractEdge)
                push!(edges, getfield(a, f))
            end
        end
    end
    return edges
end

function balance_term_matches(term::BalanceTerm, e::AbstractEdge, var::Symbol)
    if term.var != var
        return false
    elseif term.obj === e
        return true
    elseif term.obj isa Symbol
        return term.obj == id(e)
    elseif term.obj isa AbstractEdge
        return id(term.obj) == id(e)
    end
    return false
end

function balance_time_index(y::Union{AbstractVertex,AbstractEdge}, t::Int64)
    time_idx = findfirst(isequal(t), time_interval(y))
    isnothing(time_idx) && error("Time $t is not in the time interval for $(id(y))")
    return time_idx
end

function balance_term_coefficient(
    data::BalanceData,
    e::AbstractEdge,
    v::AbstractVertex,
    t::Int64,
    var::Symbol = :flow,
)
    time_index = balance_time_index(v, t)
    coeff = sum(
        (
            resolve_balance_coeff(term, v, time_index) for term in data.terms
            if balance_term_matches(term, e, var)
        );
        init = 0.0,
    )
    if coeff != 0.0
        return coeff
    elseif isempty(data.terms) && data.constant == 0.0
        return 1.0
    end
    return 0.0
end

function lossy_edge(e::AbstractEdge)
    a = loss_fraction(e)
    if isempty(a)
        return false
    else
        if any(a.>0.0)
            return true
        else
            return false
        end
    end
end

function update_balances!(e::AbstractEdge, model::Model)

    update_balance_start!(e, model)

    update_balance_end!(e, model)

end

function update_startup_fuel_balance!(e::EdgeWithUC)

    # The startup fuel will not contribute to the end vertex balance as it is not consumed there.

    v = start_vertex(e);

    i = startup_fuel_balance_id(e)

    if haskey(v.balance_data, i) && startup_fuel_consumption(e) > 0
        balance_coeff = -1 * startup_fuel_consumption(e) * capacity_size(e)
        balance_expr = get_balance(v,i)
        for t in time_interval(e)
            add_to_expression!(balance_expr[t], balance_coeff, ustart(e, t))
        end
    end

    return nothing

end

function add_flow_to_vertex_balances!(e::AbstractEdge, v::AbstractVertex, effective_flow, outgoing::Bool)
    # effective_flow is <: AbstractVector{AffExpr} or AbstractVector{VariableRef}
    if outgoing
        flow_dir = -1.0
    else
        flow_dir = 1.0
    end
    for i in keys(v.balance_data)
        data = balance_data(v, i)
        if isempty(data.terms) && data.constant == 0.0
            balance_expr = get_balance(v, i)
            for t in time_interval(e)
                add_to_expression!(balance_expr[t], flow_dir, effective_flow[t])
            end
            continue
        end
        scalar_coeff = 0.0
        has_matching_flow_term = false
        has_time_varying_coeff = false
        for term in data.terms
            if balance_term_matches(term, e, :flow)
                has_matching_flow_term = true
                if term.coeff isa Float64
                    scalar_coeff += term.coeff
                else
                    has_time_varying_coeff = true
                end
            end
        end
        if !has_matching_flow_term
            continue
        end

        balance_expr = get_balance(v, i)
        if !has_time_varying_coeff
            balance_coeff = flow_dir * scalar_coeff
            if balance_coeff == 0.0
                continue
            end
            for t in time_interval(e)
                add_to_expression!(balance_expr[t], balance_coeff, effective_flow[t])
            end
            continue
        end

        for (time_index, t) in enumerate(time_interval(e))
            balance_coeff = scalar_coeff
            for term in data.terms
                if balance_term_matches(term, e, :flow) && !(term.coeff isa Float64)
                    balance_coeff += resolve_balance_coeff(term, v, time_index)
                end
            end
            balance_coeff *= flow_dir
            if balance_coeff == 0.0
                continue
            end
            add_to_expression!(balance_expr[t], balance_coeff, effective_flow[t])
        end
    end
end

function update_balance_start!(e::AbstractEdge, model::Model)
    # This implicitly works for UnidirectionalEdge and EdgeWithUC
    # BidirectionalEdge is handled in a separate method
    v = start_vertex(e)
    effective_flow = @expression(model, [t in time_interval(e)], flow(e, t))
    add_flow_to_vertex_balances!(e, v, effective_flow, true)
end

function update_balance_start!(e::BidirectionalEdge, model::Model)
    v = start_vertex(e)
    if lossy_edge(e)
        flow_pos = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWPOS_$(id(e))_period$(period_index(e))")
        flow_neg = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWNEG_$(id(e))_period$(period_index(e))")
        @constraint(model, [t in time_interval(e)], flow_pos[t] - flow_neg[t] == flow(e, t))
        if has_capacity(e) && any(isa.(e.constraints, CapacityConstraint))
            @constraint(model, [t in time_interval(e)], flow_pos[t] + flow_neg[t] <= availability(e, t) * capacity(e))
        end
        effective_flow = @expression(model, [t in time_interval(e)], flow_pos[t] - (1 - loss_fraction(e,t)) * flow_neg[t])
    else
        effective_flow = @expression(model, [t in time_interval(e)], flow(e, t))
    end
    add_flow_to_vertex_balances!(e, v, effective_flow, true)
end

function update_balance_end!(e::AbstractEdge, model::Model)
    v = end_vertex(e)
    effective_flow = @expression(model, [t in time_interval(e)], (1-loss_fraction(e,t)) * flow(e, t))
    add_flow_to_vertex_balances!(e, v, effective_flow, false)
end

function update_balance_end!(e::BidirectionalEdge, model::Model)
    v = end_vertex(e)
    if lossy_edge(e)
        flow_pos = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWPOS_$(id(e))_period$(period_index(e))")
        flow_neg = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWNEG_$(id(e))_period$(period_index(e))")
        @constraint(model, [t in time_interval(e)], flow_pos[t] - flow_neg[t] == flow(e, t))
        if has_capacity(e) && any(isa.(e.constraints, CapacityConstraint))
            @constraint(model, [t in time_interval(e)], flow_pos[t] + flow_neg[t] <= availability(e, t) * capacity(e))
        end        
        effective_flow = @expression(model, [t in time_interval(e)], (1 - loss_fraction(e,t)) * flow_pos[t] - flow_neg[t])
    else
        effective_flow = @expression(model, [t in time_interval(e)], flow(e, t))
    end
    add_flow_to_vertex_balances!(e, v, effective_flow, false)
end
