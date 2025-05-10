struct Stages
    systems::Vector{System}
    settings::Union{NamedTuple,Nothing}
end
solution_algorithm(stages::Stages) = solution_algorithm(stages.settings[:SolutionAlgorithm])

function generate_stages(
    path::AbstractString,
    systems_data::Dict{Symbol,Any},
)::Stages

    stages = systems_data[:stages]
    num_stages = length(stages)
    @info("Running system generation for $num_stages stages")
    
    start_time = time()
    systems::Vector{System} = map(1:num_stages) do stage_idx
        system_data = stages[stage_idx]
        system_data[:time_data][:StageIndex] = stage_idx
        stage_system = empty_system(dirname(path))
        generate_system!(stage_system, system_data)
        return stage_system
    end

    settings = configure_stages(systems_data[:settings], dirname(path))

    prepare_stages!(systems, settings)

    @info("Done generating stages. It took $(round(time() - start_time, digits=2)) seconds")
    return Stages(systems, settings)
end


function prepare_stages!(systems::Vector{System}, settings::NamedTuple)
    for (stage_id, system) in enumerate(systems)
        @info("Discounting fixed costs for stage $(stage_id)")
        if !isa(solution_algorithm(settings[:SolutionAlgorithm]), Myopic)
            ### Note that myopic simulations do not use discount factors
            discount_fixed_costs!(system, settings)
        end
        @info("Computing retirement stages for stage $(stage_id)")
        compute_retirement_stage!(system, settings[:StageLengths])
    end
end