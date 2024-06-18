constraint_value(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_value];

constraint_dual(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_dual];

constraint_ref(c::AbstractTypeConstraint) = c.contraint_dict[:constraint_ref];



function add_all_model_constraints!(
    y::Union{AbstractEdge,AbstractNode,AbstractTransformationEdge},
    model::Model,
)

    for ct in all_constraints(y)
        add_model_constraint!(ct, y, model)
    end
    ##### This does not work because can't broadcast when passing g : add_model_constraints!.(all_constraints(g),g,model);

    return nothing
end

function add_all_model_constraints!(y::AbstractTransform, model::Model)

    for ct in all_constraints(y)
        add_model_constraint!(ct, y, model)
    end

    return nothing
end

