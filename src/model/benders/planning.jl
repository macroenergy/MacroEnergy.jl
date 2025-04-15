
function initialize_planning_problem!(stages::Stages,opt::Dict)
    
    planning_problem, linking_variables = generate_planning_problem(stages);

    if opt[:solver] == Gurobi.Optimizer
        optimizer = create_optimizer(opt[:solver], GRB_ENV[], opt[:attributes])
    else
        optimizer = create_optimizer(opt[:solver], missing, opt[:attributes])
    end

    set_optimizer(planning_problem, optimizer)

    set_silent(planning_problem)

    if stages.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(planning_problem)
    end

    return planning_problem,linking_variables

end
function generate_planning_problem(stages::Stages)
    generate_planning_problem(stages, expansion_mode(stages))
end

function generate_planning_problem(stages::Stages,::SingleStage)
    generate_planning_problem(stages.systems[1])
end

function generate_planning_problem(stages::Stages,::PerfectForesight)

    @info("Generating multistage planning problem with perfect foresight")

    systems = stages.systems
    settings = stages.settings

    start_time = time();

    model = Model()

    @variable(model, vREF == 1)

    number_of_stages = length(systems)

    fixed_cost = Dict()

    linking_variables = Vector{String}();

    for s in 1:number_of_stages

        @info(" -- Stage $s")

        model[:eFixedCost] = AffExpr(0.0)

        prev_variables = all_variables(model);
        @info(" -- Adding linking variables")
        add_linking_variables!(systems[s], model) 
        append!(linking_variables, name.(setdiff(all_variables(model), prev_variables)))
        
        @info(" -- Defining available capacity")
        define_available_capacity!(systems[s], model)

        @info(" -- Generating planning model")
        planning_model!(systems[s], model)

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(systems[s].assets, model)

        #### Removing for now, needs more testing
        ##### add_feasibility_constraints!(systems[s], model)

        if s < number_of_stages
            @info(" -- Available capacity in stage $(s) is being carried over to stage $(s+1)")
            carry_over_capacities!(systems[s+1], systems[s])
        end

        fixed_cost[s] = model[:eFixedCost];
        unregister(model,:eFixedCost)

    end

    model[:eAvailableCapacity] = get_available_capacity(systems);

    #The settings are the same in all stages, we have a single settings file that gets copied into each system struct
    stage_lengths = collect(settings.StageLengths)

    wacc = settings.WACC

    cum_years = [sum(stage_lengths[i] for i in 1:s-1; init=0) for s in 1:number_of_stages];

    discount_factor = 1 ./ ( (1 + wacc) .^ cum_years)

    @expression(model,eFixedCost, sum(discount_factor[s] * fixed_cost[s] for s in 1:number_of_stages))

    number_of_subproblems = sum(length(system.time_data[:Electricity].subperiods) for system in systems)

    stage_map = get_subproblem_to_stage_mapping(systems);

    @variable(model, vTHETA[w in 1:number_of_subproblems] .>= 0)

    opexmult = [sum([1 / (1 + wacc)^(i - 1) for i in 1:stage_lengths[s]]) for s in 1:number_of_stages]

    @expression(model,eApproximateVariableCost, sum(discount_factor[stage_map[w]] * opexmult[stage_map[w]] * vTHETA[w] for w in 1:number_of_subproblems))

    @objective(model, Min, model[:eFixedCost] + model[:eApproximateVariableCost])

    @info(" -- Planning problem generation complete, it took $(time() - start_time) seconds")

    return model, linking_variables

end

function generate_planning_problem(system::System)
    @info("Generating planning problem for single stage expansion")

    number_of_subproblems = length(system.time_data[:Electricity].subperiods);

    start_time = time();

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    planning_model!(system, model)

    #### Removing for now, needs more testing  
    #### add_feasibility_constraints!(system, model)

    model[:eAvailableCapacity] = get_available_capacity([system]);

    @variable(model, vTHETA[w in 1:number_of_subproblems] .>= 0)

    @expression(model,eApproximateVariableCost, sum(vTHETA[w] for w in 1:number_of_subproblems))

    @objective(model, Min, model[:eFixedCost] + model[:eApproximateVariableCost])

    @info(" -- Planning problem generation complete, it took $(time() - start_time) seconds")

    return model, linking_variables

end

function get_available_capacity(systems::Vector{System})
    
    AvailableCapacity = Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}}();

    for system in systems
        AvailableCapacity = get_available_capacity!(system,AvailableCapacity)
    end

    return AvailableCapacity
end

function get_available_capacity!(system::System, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})
    
    for a in system.assets
        get_available_capacity!(a, AvailableCapacity)
    end

    return AvailableCapacity
end

function get_available_capacity!(a::AbstractAsset, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    for t in fieldnames(typeof(a))
        get_available_capacity!(getfield(a, t), AvailableCapacity)
    end

end

function get_available_capacity!(n::Node, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    return nothing

end


function get_available_capacity!(g::Transformation, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    return nothing

end

function get_available_capacity!(g::AbstractStorage, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    AvailableCapacity[g.id,stage_index(g)] = g.capacity;

end


function get_available_capacity!(e::AbstractEdge, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    AvailableCapacity[e.id,stage_index(e)] = e.capacity;

end

#### Removing for now, needs more testing  
# function add_feasibility_constraints!(system::System, model::Model)
#     all_edges = edges(system.assets)
#     for n in system.locations
#         if isa(n, Node)
#             if !all(max_supply(n) .== 0)
#                 edges_that_start_from_n = all_edges[findall(start_vertex(e) == n && e.unidirectional == true for e in all_edges)]
#                 @info "Adding feasibility constraints for node $(n.id)"
#                 @constraint(model, sum(capacity(e) for e in edges_that_start_from_n) <= sum(max_supply(n)))    
#             end
#         end
#     end
#     return nothing
# end
