struct Stages
    systems::Vector{System}
    settings::Union{NamedTuple,Nothing}
end
algorithm_type(stages::Stages) = algorithm_type(stages.settings[:SolutionAlgorithm])