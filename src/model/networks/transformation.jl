Base.@kwdef mutable struct Transformation <: AbstractVertex
    @AbstractVertexBaseAttributes()
end

function add_linking_variables!(g::Transformation, model::Model)
    return nothing
end


function planning_model!(g::Transformation, model::Model)

    return nothing
end

function define_available_capacity!(g::Transformation, model::Model)
    return nothing
end

function operation_model!(g::Transformation, model::Model)
    if !isempty(balance_ids(g))
        for i in balance_ids(g)
            g.operation_expr[i] =
                @expression(model, [t in time_interval(g)], 0 * model[:vREF])
        end
    end
    return nothing
end
