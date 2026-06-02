"""
Implements endogenous technological learning constraints. The main output is the endogenous investment cost, called "endog_annualized_investment_cost_times_newcapacity", which is used in edge.jl for any learning technologies

Inputs:
Takes a system input because we need to combine new_capacity across edges of the same "learning_type" attribute to determine the amount of learning for a given technology. e.g., solar costs depend on total capacity expansion across all solar edges.
"""
function add_learning!(system::System, model::Model, period_idx::Int, settings::NamedTuple)

    learning_techs = settings[:LearningTechnologies]
    n_learning_techs = length(learning_techs)

    n_segments = 5
    # Segment of piece-wise linear curve chosen for each learning technology
    endogenous_capex_segment_chosen = @variable(model, [y in 1:n_learning_techs, k in 1:n_segments+1], binary=true, base_name = "vBINSEG_LEARNINGTYPE_$(period_idx)_$(y)_seg_$k")
    @constraint(model, [y in 1:n_learning_techs], sum(endogenous_capex_segment_chosen[y,k] for k in 1:n_segments+1) == 1)

    for learning_tech in learning_techs

        learning_tech_edges = get_edges_of_type(system, learning_tech)
        
        for e in learning_tech_edges

            if max_cumul_capacity(e) == Inf || max_cumul_capacity(e) == -1
                error(string(e.id, " is a learning technology but max cumulative capacity is not specified"))
            end

            # Find position in learning techs list
            learning_type_index = findfirst(x -> x == learning_type(e), learning_techs)
            
            # Define (x,y) coordinates for piece-wise linear curve (cumulative cost as a function of cumulative capacity added)
            # TODO: Points do not have to be defined inside this loop
            x_points, y_points = compute_pwl_coordinates(n_segments, init_cumul_capacity(e), max_cumul_capacity(e), investment_cost(e), learning_parameter(e))

            # Compute slopes of piece-wise linear curve
            # First segment represents no new capacity and no learning
            push!(e.pwl_capex_slopes, investment_cost(e))
            # Remaining segments:
            for k in 2:n_segments+1
                push!(e.pwl_capex_slopes, (y_points[k] - y_points[k-1])/(x_points[k]-x_points[k-1]))
            end
            
            e.cumulative_experience = @variable(model, [k in 1:n_segments+1], lower_bound = 0.0, base_name = "vCUMULCAP_$(id(e))_stage$(period_index(e))")
            
            # Learning is delayed by e.g. length of construction
            curr_period = period_index(e)
            cost_period = curr_period - learning_delay(e)

            # Cumulative_experience combines existing capacity and all new capacity from modeled region
            @constraint(model, sum(cumulative_experience(e)[k] for k in 1:n_segments+1) == sum(new_capacity_track(e,i) for i=1:curr_period, e in learning_tech_edges) + init_cumul_capacity(e))
            
            println(string(e.id," points"))
            println(x_points)
            println(y_points)
            println("All slopes")
            println(e.pwl_capex_slopes)

            # Determine chosen segment
            epsilon_learning = init_cumul_capacity(e)/1e6 # ensures the first inequality is strict
            ϵ = ones(length(x_points))*epsilon_learning 
            # Set segment
            @constraint(model, [k in 2:n_segments+1], cumulative_experience(e)[k] >= (x_points[k-1] + ϵ[k-1]) * endogenous_capex_segment_chosen[learning_type_index, k])
            @constraint(model, [k in 1:n_segments+1], cumulative_experience(e)[k] <= x_points[k] * endogenous_capex_segment_chosen[learning_type_index, k])

            # Slope reached after building new capacity
            e.endogenous_capex = @expression(model, sum(endogenous_capex_segment_chosen[learning_type_index, k] * pwl_capex_slopes(e)[k] for k in 1:n_segments+1))
            e.endogenous_capex_track[period_index(e)] = endogenous_capex(e)
            e.endogenous_capex_segment_chosen_track[period_index(e)] = endogenous_capex_segment_chosen[learning_type_index, :]
            
            # Determine investment cost
            # Depends on learning lag
            if curr_period <= learning_delay(e)
                # No learning yet, use initial investment cost
                e.endog_annualized_investment_cost = annualized_investment_cost(e)

                e.endog_annualized_investment_cost_times_newcapacity = annualized_investment_cost(e)*new_capacity(e)

                 # For reporting purposes
                e.endogenous_capex_segment_chosen_from_relevant_period = endogenous_capex_segment_chosen_track(e, curr_period)
                e.endog_annualized_cost = annualized_investment_cost(e)

            else
                e.endogenous_capex_segment_chosen_from_relevant_period = endogenous_capex_segment_chosen_track(e, cost_period)
                # Begin Linearize 
                e.aux_new_capacity = @variable(model, [k in 1:n_segments+1], lower_bound = 0.0, base_name = "vAUXNEWCAP_$(id(e))_stage$(period_index(e))_seg_$k")

                # Upper bound on new capacity in a given period

                @constraint(model, [k in 1:n_segments+1], e.new_capacity - e.aux_new_capacity[k] >= 0)
                # Big M constraints
                big_M_capacity = max_new_capacity(e)
                if big_M_capacity == Inf || big_M_capacity == -1
                     error("$(e.id) is a learning technology but max_new_capacity is not specified (required for big-M linearization)")
                 end
                @constraint(model, [k in 1:n_segments+1], e.new_capacity - e.aux_new_capacity[k] <= big_M_capacity*(1-endogenous_capex_segment_chosen_from_relevant_period(e)[k]))
                @constraint(model, [k in 1:n_segments+1], e.aux_new_capacity[k] <= big_M_capacity*e.endogenous_capex_segment_chosen_from_relevant_period[k])

                # Cost term for objective function
                e.endog_annualized_investment_cost_times_newcapacity = @expression(model, sum(e.pwl_capex_slopes[k]*e.aux_new_capacity[k]*capital_recovery_factor(wacc(e), capital_recovery_period(e)) for k in 1:n_segments+1))

                ### Enf of linearization
                
                # For reporting purposes
                e.endog_annualized_cost = @expression(model, sum(e.pwl_capex_slopes[k]*e.endogenous_capex_segment_chosen_from_relevant_period[k]*capital_recovery_factor(wacc(e), capital_recovery_period(e)) for k in 1:n_segments+1))
                
            end
        end
        
    end
    return nothing
end

"""
Collects edges that belong to the same learning type
"""
function get_edges_of_type(system::System, type::String)

    tech_edges = Vector{AbstractEdge}()
    edges = get_edges(system)
    for e in edges 
        if learning_type(e) == type
            push!(tech_edges, e)
        end
    end
    return tech_edges
end

function compute_pwl_coordinates(n_segments::Int, init_cumul_capacity::Float64, max_cumul_capacity::Float64, investment_cost::Float64, learning_parameter::Float64)

    x_points = zeros(n_segments+1)
    y_points = zeros(n_segments+1)
    
    # Define end points
    x_points[1] = init_cumul_capacity
    x_points[end] = max_cumul_capacity
    
    # X coordinates for piece-wise linear curve
    # X points are spaced exponentially
    for k in 2:n_segments
        x_points[k] = max_cumul_capacity/(2^(n_segments - k +1))
    end

    # Compute Y coordinates
    for k in 1:n_segments+1        
        cost_point = investment_cost*(x_points[k]/init_cumul_capacity)^(-learning_parameter)
        # Estimate cost from fixed capacity points
        y_points[k] = (1/(1-learning_parameter))*(x_points[k]*cost_point-investment_cost*init_cumul_capacity)
    end
    return x_points, y_points
end
