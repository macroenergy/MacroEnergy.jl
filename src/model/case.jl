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

    case = systems_data[:case]
    num_systems = length(case)
    @info("Running system generation")
    
    start_time = time()
    systems::Vector{System} = map(1:num_systems) do system_idx
        system_data = case[system_idx]
        system_data[:time_data][:SystemIndex] = system_idx
        system = empty_system(dirname(path))
        generate_system!(system, system_data)
        return system
    end

    settings = configure_case(systems_data[:settings], dirname(path))

    prepare_case!(systems, settings)

    @info("Done generating case. It took $(round(time() - start_time, digits=2)) seconds")
    return Case(systems, settings)
end


function prepare_case!(systems::Vector{System}, settings::NamedTuple)
    for (system_id, system) in enumerate(systems)
        compute_annualized_costs!(system,settings) 
        
        @info("Discounting fixed costs for period $(system_id)")
        discount_fixed_costs!(system, settings)
        
        @info("Computing retirement case for period $(system_id)")
        compute_retirement_period!(system, settings[:PeriodLengths])
    end
end