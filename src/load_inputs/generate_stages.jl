function generate_stages(
    path::AbstractString,
    systems_data::Dict{Symbol,Any},
)::Stages

    stages = systems_data[:stages]
    num_stages = length(stages)
    @info("Running system generation for $num_stages stages")
    
    start_time = time()
    systems::Vector{System} = map(1:num_stages) do stage_idx
        stage_system = empty_system(dirname(path))
        generate_system!(stage_system, stages[stage_idx])
        return stage_system
    end

    settings = configure_stages(systems_data[:settings], dirname(path))

    prepare_stages!(systems, settings)
    # prepare_stages!(systems, settings[:SolutionAlgorithm])

    @info("Done loading stages. It took $(round(time() - start_time, digits=2)) seconds")
    return Stages(systems, settings)
end

function prepare_stages!(systems::Vector{System}, settings::NamedTuple)
    solution_algorithm = settings[:SolutionAlgorithm]
    prepare_stages!(systems, settings, solution_algorithm)
end

function prepare_stages!(systems::Vector{System}, settings::NamedTuple, ::PerfectForesight)
    for (stage_id, system) in enumerate(systems)
        @info("Discounting fixed costs for stage $(stage_id)")
        discount_fixed_costs!(system, settings)
        @info("Computing retirement stages for stage $(stage_id)")
        compute_retirement_stage!(system, settings[:StageLengths])
    end
end

function prepare_stages!(systems::Vector{System}, settings::NamedTuple, ::Myopic)
    for (stage_id, system) in enumerate(systems)
        @info("Computing retirement stages for stage $(stage_id)")
        compute_retirement_stage!(system, settings[:StageLengths])
    end
end