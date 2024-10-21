function get_subperiod_index(system::System)

    return system.time_data[:Electricity].subperiod_indices[1]

end

function generate_decomposed_system(system_full::System)

    subperiod_indices = collect(eachindex(system_full.time_data[:Electricity].subperiods))

    system_decomp = Dict{Int64,System}()

    for w in subperiod_indices
        system_decomp[w] = deepcopy(system_full)
        for c in keys(system_full.time_data)
            system_decomp[w].time_data[c].time_interval =
                system_full.time_data[c].subperiods[w]
            system_decomp[w].time_data[c].subperiod_weights =
                Dict(w => system_full.time_data[c].subperiod_weights[w])
            system_decomp[w].time_data[c].subperiods =
                [system_full.time_data[c].subperiods[w]]
            system_decomp[w].time_data[c].subperiod_indices = [w]
        end
    end

    return system_decomp
end

function generate_planning_problem(system::System)

    subperiod_indices = collect(eachindex(system.time_data[:Electricity].subperiods))

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    model[:eTotalCapacity] = Dict{Symbol, AffExpr}();

    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    planning_model!(system, model)

    @variable(model, vTHETA[w in subperiod_indices] .>= 0)

    @objective(model, Min, model[:eFixedCost] + sum(vTHETA))

    return model, linking_variables

end


function generate_operation_subproblem(system::System)

    model = Model()

    @variable(model, vREF == 1)

    model[:eVariableCost] = AffExpr(0.0)
    
    model[:eTotalCapacity] = Dict{Symbol, AffExpr}();

    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    operation_model!(system, model)

    @objective(model, Min, model[:eVariableCost])

    return model, linking_variables


end