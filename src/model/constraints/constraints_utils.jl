constraint_value(c::AbstractTypeConstraint) = c.constraint_value;
constraint_dual(c::AbstractTypeConstraint) = c.constraint_dual;
constraint_ref(c::AbstractTypeConstraint) = c.constraint_ref;

# Fallback: constraints that don't need settings just ignore it
function add_model_constraint!(c::AbstractTypeConstraint, y::Union{AbstractEdge,AbstractVertex}, model::Model, settings::NamedTuple)
    add_model_constraint!(c, y, model)
end

function add_constraints_by_type!(system::System, model::Model, constraint_type::DataType)

    for n in system.locations
        add_constraints_by_type!(n, model, constraint_type)
    end

    for a in system.assets
        for t in fieldnames(typeof(a))
            add_constraints_by_type!(getfield(a, t), model, constraint_type)
        end
    end

    return nothing
end

function add_constraints_by_type!(
    y::Union{AbstractEdge,AbstractVertex},
    model::Model,
    ::Type{C},
) where {C<:AbstractTypeConstraint}
    for c in all_constraints(y)
        if c isa C
            add_model_constraint!(c, y, model)
        end
    end

    return nothing
end

function add_constraints_by_type!(
    location::Location, 
    model::Model,
    constraint_type::DataType
)
    return nothing
end

### Overloaded functions with settings
function add_constraints_by_type!(system::System, model::Model, constraint_type::DataType, settings::NamedTuple)

    for n in system.locations
        add_constraints_by_type!(n, model, constraint_type, settings)
    end

    for a in system.assets
        for t in fieldnames(typeof(a))
            add_constraints_by_type!(getfield(a, t), model, constraint_type, settings)
        end
    end

    return nothing
end

function add_constraints_by_type!(
    y::Union{AbstractEdge,AbstractVertex},
    model::Model,
    ::Type{C},
    settings::NamedTuple,
) where {C<:AbstractTypeConstraint}
    for c in all_constraints(y)
        if c isa C
            add_model_constraint!(c, y, model, settings)
        end
    end

    return nothing
end

function add_constraints_by_type!(
    location::Location,
    model::Model,
    constraint_type::DataType,
    settings::NamedTuple
)
    return nothing
end
### End overloaded functions with settings 

const CONSTRAINT_TYPES = Dict{Symbol,DataType}()

function register_constraint_types!(m::Module = MacroEnergy)
    empty!(CONSTRAINT_TYPES)
    for (constraint_name, constraint_type) in all_subtypes(m, :AbstractTypeConstraint)
        CONSTRAINT_TYPES[constraint_name] = constraint_type
    end
    return nothing
end

function constraint_types(m::Module = MacroEnergy)
    isempty(CONSTRAINT_TYPES) && register_constraint_types!(m)
    return CONSTRAINT_TYPES
end
