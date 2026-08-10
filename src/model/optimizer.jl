# JuMP.set_optimizer
struct Optimizer
    optimizer::DataType
    optimizer_env::Any
    attributes::Tuple
end

function create_optimizer(optimizer::DataType, optimizer_env::Any=nothing, attributes::Tuple=())
    return Optimizer(optimizer, optimizer_env, attributes)
end

function set_optimizer(model::Model, opt::Optimizer)
    if !isnothing(opt.optimizer_env)
        @debug("Setting optimizer with environment $(opt.optimizer_env)")
        try 
            set_optimizer(model, () -> opt.optimizer(opt.optimizer_env));
        catch e
            error("Error creating optimizer with environment: $e")
        end
    else
        @debug("Setting optimizer $(opt.optimizer)")
        set_optimizer(model, opt.optimizer);
    end
    @debug("Setting optimizer attributes $(opt.attributes)")
    set_optimizer_attributes(model, opt)
end

function set_optimizer(models::Vector{Model}, opt::Optimizer)
    for model in models
        set_optimizer(model, opt)
        set_optimizer_attributes(model, opt)
    end
end

function set_optimizer_attributes(model::Model, opt::Optimizer)
    try
        set_optimizer_attributes(model, opt.attributes...)
    catch
        @warn("Error setting optimizer attributes. Check that the optimizer is valid.")
    end
end

function create_optimizer_benders(
    planning_optimizer::DataType,
    subproblem_optimizer::DataType,
    planning_optimizer_attributes::Tuple,
    subproblem_optimizer_attributes::Tuple
)
    return Dict(
        :planning => Dict(:solver => planning_optimizer, :attributes => planning_optimizer_attributes),
        :subproblems => Dict(:solver => subproblem_optimizer, :attributes => subproblem_optimizer_attributes),
    )
end
