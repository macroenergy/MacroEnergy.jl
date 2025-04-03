function get_subperiod_index(system::System)

    return system.time_data[:Electricity].subperiod_indices[1]

end

function generate_decomposed_system(system_full::System)

    subperiod_indices = system_full.time_data[:Electricity].subperiod_indices;
    subperiods = system_full.time_data[:Electricity].subperiods;
    subperiod_weights = system_full.time_data[:Electricity].subperiod_weights;

    number_of_subperiods = length(subperiod_indices);

    system_decomp = Vector{System}(undef,number_of_subperiods)

    for i in 1:number_of_subperiods
        system_decomp[i] = deepcopy(system_full)
        w = subperiod_indices[i];

        for c in keys(system_full.time_data)
            system_decomp[i].time_data[c].time_interval = subperiods[i]
            system_decomp[i].time_data[c].subperiod_weights = Dict(w => subperiod_weights[w])
            system_decomp[i].time_data[c].subperiods = [subperiods[i]]
            system_decomp[i].time_data[c].subperiod_indices = [w]
            system_decomp[i].time_data[c].period_map = Dict(w => w)
        end
    end

    return system_decomp
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


function generate_operation_subproblem(system::System)

    model = Model()

    @variable(model, vREF == 1)

    model[:eVariableCost] = AffExpr(0.0)
    
    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    operation_model!(system, model)

    @objective(model, Min, model[:eVariableCost])

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

function default_benders_settings()
    return Dict(
        :MaxIter=> 50,
        :MaxCpuTime => 7200,
        :ConvTol => 1e-3,
        :StabParam => 0.0,
        :StabDynamic => false,
        :IntegerInvestment => false
    )
end

function configure_benders(
    path::AbstractString,
    rel_path::AbstractString,
)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "benders_settings.json")
    end
    if !isfile(path)
        error("Settings file not found: $path")
    end
    return configure_benders(read_file(path))
end

function configure_benders(
    benders_settings::AbstractDict{Symbol,Any},
    rel_path::AbstractString,
)
    if haskey(benders_settings, :path)
        @info("Configuring benders from path")
        path = rel_or_abs_path(benders_settings[:path], rel_path)
        return configure_benders(path, rel_path)
    else
        return configure_benders(benders_settings)
    end
end

function configure_benders(benders_settings::AbstractDict{Symbol,Any})
    @info("Configuring benders")
    settings = default_benders_settings()
    settings = merge(settings, benders_settings)
    validate_benders_settings(settings)
    return namedtuple(settings)
end

function validate_benders_settings(benders_settings::AbstractDict{Symbol,Any})
    return true #to be done
end