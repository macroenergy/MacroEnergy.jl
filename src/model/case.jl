struct Case
    systems::Vector{System}
    settings::Union{NamedTuple,Nothing}
end
solution_algorithm(case::Case) = solution_algorithm(case.settings[:SolutionAlgorithm])
number_of_periods(case::Case) = length(case.systems)
get_periods(case::Case) = case.systems
get_settings(case::Case) = case.settings

function generate_case(
    path::AbstractString,
    systems_data::Dict{Symbol,Any},
)::Case

    @info("*** Generating case ***")

    settings = configure_case(systems_data[:settings], dirname(path))

    case = systems_data[:case]
    num_systems = length(case)

    # Check that the number of systems matches the length of [PeriodLengths]
    if num_systems != length(settings[:PeriodLengths])
        error(
            "Your number of systems ($(num_systems)) does not match the number of periods lengths ($(length(settings[:PeriodLengths]))) in your case settings.
            If you didn't specify period lengths, the default is for one 1-year period"
            )
    end

    @info("Generating systems")
    
    start_time = time()
    systems::Vector{System} = map(1:num_systems) do system_idx
        system_data = case[system_idx]
        system_data[:time_data][:SystemIndex] = system_idx
        system = empty_system(dirname(path))
        generate_system!(system, system_data)
        return system
    end

    @debug("Case settings: $(settings)")

    prepare_case!(systems, settings)

    @info("*** Done generating case. It took $(round(time() - start_time, digits=2)) seconds ***")
    return Case(systems, settings)
end


function prepare_case!(systems::Vector{System}, settings::NamedTuple)
    for (system_id, system) in enumerate(systems)
        compute_annualized_costs!(system,settings) 
        
        @info(" -- Discounting fixed costs for period $(system_id)")
        discount_fixed_costs!(system, settings)
        
        @info(" -- Computing retirement case for period $(system_id)")
        compute_retirement_period!(system, settings[:PeriodLengths])

        if system_id==1
            initialize_min_retired_capacity_track!(system)
        else
            track_min_retired_capacity!(system,systems[system_id-1])
        end
    end


end

function initialize_min_retired_capacity_track!(system::System)
    
    for a in system.assets
        for t in fieldnames(typeof(a))
            y = getfield(a,t)
            if :min_retired_capacity ∈ Base.fieldnames(typeof(y))
                y.min_retired_capacity_track = min_retired_capacity(y)
            end
        end
    end

    return nothing
end

function track_min_retired_capacity!(system::System, system_prev::System)
    
    for a in system.assets
        a_prev_index = findfirst(id.(system_prev.assets).==id(a))
        if !isnothing(a_prev_index)
            a_prev = system_prev.assets[a_prev_index];
            track_min_retired_capacity!(a, a_prev)
        end
    end

    return nothing
end

function track_min_retired_capacity!(a::AbstractAsset, a_prev::AbstractAsset)

    for t in fieldnames(typeof(a))
        y = getfield(a,t)
        y_prev = getfield(a_prev,t)
        if :min_retired_capacity ∈ Base.fieldnames(typeof(y))
            y.min_retired_capacity_track = min_retired_capacity_track(y_prev)  + min_retired_capacity(y)
        end
    end

end
