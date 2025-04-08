struct Stages
    systems::Vector{System}
    settings::Union{NamedTuple,Nothing}
end
expansion_mode(stages::Stages) = expansion_mode(stages.settings[:ExpansionMode])
solution_algorithm(stages::Stages) = solution_algorithm(stages.settings[:SolutionAlgorithm])