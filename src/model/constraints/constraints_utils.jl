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

    # Add retrofitting constraints
    if constraint_type == PlanningConstraint
        edges = get_edges(system)
        retrofit_tuples = get_unique_retrofit_tuples(system)
        @constraint(model, cRetrofitCapacity[(retrofit_id, retrofit_location) in retrofit_tuples],
        sum(retrofitted_capacity(e) for e in get_can_retrofit_edges(edges, retrofit_id, retrofit_location)) ==
        sum((new_capacity(e)/retrofit_efficiency(e)) for e in get_is_retrofit_edges(edges, retrofit_id, retrofit_location))
    )
    end
end

function add_constraints_by_type!(
    y::Union{AbstractEdge,AbstractVertex},
    model::Model,
    constraint_type::DataType,
)
    for c in all_constraints(y)
        if isa(c, constraint_type)
            add_model_constraint!(c, y, model)
        end
    end
end
function add_constraints_by_type!(
    location::Location, 
    model::Model,
    constraint_type::DataType
)
    return nothing
end

function get_unique_retrofit_tuples(system::System)
    can_retrofit_tuples = []
    is_retrofit_tuples = []
    for e in get_edges(system)
        if can_retrofit(e)
            push!(can_retrofit_tuples, (retrofit_id(e), location(e)))
        end
        if is_retrofit(e)
            push!(is_retrofit_tuples, (retrofit_id(e), location(e)))
        end
    end
    @assert unique(can_retrofit_tuples) == unique(is_retrofit_tuples)
    retrofit_tuples = unique(can_retrofit_tuples)
    return retrofit_tuples
end

function get_can_retrofit_edges(edges, cluster_retrofit_id, cluster_location)
    # Returns the edges that can be retrofitted with a given retrofit_id and location
    can_retrofit_edges = []
    for e in edges
        if (can_retrofit(e) == true) && (retrofit_id(e) == cluster_retrofit_id) && (location(e) == cluster_location)
            push!(can_retrofit_edges, e)
        end
    end
    return can_retrofit_edges
end

function get_is_retrofit_edges(edges, cluster_retrofit_id, cluster_location)
    # Returns the edges that can retrofit other edges with a given retrofit_id and location
    is_retrofit_edges = []
    for e in edges
        if (is_retrofit(e) == true) && (retrofit_id(e) == cluster_retrofit_id) && (location(e) == cluster_location)
            push!(is_retrofit_edges, e)
        end
    end
    return is_retrofit_edges
end

const CONSTRAINT_TYPES = Dict{Symbol,DataType}()

function register_constraint_types!(m::Module = MacroEnergy)
    empty!(CONSTRAINT_TYPES)
    for (constraint_name, constraint_type) in all_subtypes(m, :AbstractTypeConstraint)
        CONSTRAINT_TYPES[constraint_name] = constraint_type
    end
end

function constraint_types(m::Module = MacroEnergy)
    isempty(CONSTRAINT_TYPES) && register_constraint_types!(m)
    return CONSTRAINT_TYPES
end