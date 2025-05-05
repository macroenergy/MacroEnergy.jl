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
    prepare_stages!(systems, settings, expansion_mode(settings[:ExpansionMode]))
end

function prepare_stages!(systems::Vector{System}, settings::NamedTuple, ::AbstractExpansionMode)
    @debug("Default `prepare_stages!` method called. No preparation needed.")
    return nothing
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