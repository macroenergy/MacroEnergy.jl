# JuMP.set_optimizer
struct Optimizer
    optimizer::DataType
    optimizer_env::Any
    attributes::Tuple
end

function create_optimizer(optimizer::DataType, optimizer_env::Any, attributes::Tuple)
    return Optimizer(optimizer, optimizer_env, attributes)
end

function set_optimizer(model::Model, opt::Optimizer)
    if !ismissing(opt.optimizer_env)
        try 
            set_optimizer(model, () -> opt.optimizer(opt.optimizer_env));
        catch
            error("Error creating optimizer with environment. Check that the environment is valid.")
        end
    else
        set_optimizer(model, opt.optimizer);
    end
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
