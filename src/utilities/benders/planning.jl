
function initialize_planning_problem!(system::Any,optimizer::Optimizer)
    
    planning_model, linking_variables = generate_planning_problem(system);
    
    set_optimizer(planning_model, optimizer)

    set_silent(planning_model)

    return planning_model,linking_variables

end


function generate_planning_problem(system::System)

    subperiod_indices = system.time_data[:Electricity].subperiod_indices;

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    model[:eAvailableCapacity] = Dict{Symbol, AffExpr}();

    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    planning_model!(system, model)

    @variable(model, vTHETA[w in subperiod_indices] .>= 0)

    @objective(model, Min, model[:eFixedCost] + sum(vTHETA))

    return model, linking_variables

end



function get_available_capacity(system::System)
    
    AvailableCapacity = Dict{Symbol, AffExpr}();
    for a in system.assets
        get_available_capacity!(a, AvailableCapacity)
    end

    return AvailableCapacity
end

function get_available_capacity!(a::AbstractAsset, AvailableCapacity::Dict{Symbol, AffExpr})

    for t in fieldnames(typeof(a))
        get_available_capacity!(getfield(a, t), AvailableCapacity)
    end

end

function get_available_capacity!(n::Node, AvailableCapacity::Dict{Symbol, AffExpr})

    return nothing

end


function get_available_capacity!(g::Transformation, AvailableCapacity::Dict{Symbol, AffExpr})

    return nothing

end

function get_available_capacity!(g::AbstractStorage, AvailableCapacity::Dict{Symbol, AffExpr})

    AvailableCapacity[g.id] = g.capacity;

end


function get_available_capacity!(e::AbstractEdge, AvailableCapacity::Dict{Symbol, AffExpr})

    AvailableCapacity[e.id] = e.capacity;

end
