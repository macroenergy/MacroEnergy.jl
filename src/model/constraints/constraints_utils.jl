constraint_value(c::AbstractTypeConstraint) = c.constraint_value;
constraint_dual(c::AbstractTypeConstraint) = c.constraint_dual;
constraint_ref(c::AbstractTypeConstraint) = c.constraint_ref;

function add_constraints_by_type!(system::System, model::Model, constraint_type::DataType)

    for n in system.locations
        add_constraints_by_type!(n, model, constraint_type)
    end

    for a in system.assets
        for t in fieldnames(typeof(a))
            add_constraints_by_type!(getfield(a, t), model, constraint_type)
        end
    end

    for c in system.constraints
        if isa(c, constraint_type)
            add_model_constraint!(c, system, model)
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
