constraint_value(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_value];

constraint_dual(c::AbstractTypeConstraint) = c.constraint_dict[:constraint_dual];

constraint_ref(c::AbstractTypeConstraint) = c.contraint_dict[:constraint_ref];



function add_all_model_constraints!(
    y::Union{AbstractEdge,AbstractVertex},
    model::Model,
)

    for ct in all_constraints(y)
        add_model_constraint!(ct, y, model)
    end
    ##### This does not work because can't broadcast when passing g : add_model_constraints!.(all_constraints(g),g,model);

    return nothing
end


function add_all_model_constraints!(system::System,model::Model)

    add_all_model_constraints!.(system.locations, Ref(model))

    add_all_model_constraints!.(system.assets, Ref(model))

end

function add_all_model_constraints!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_all_model_constraints!(getfield(a,t), model)
    end
    return nothing
end