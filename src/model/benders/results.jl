struct PlanningSolution
    fixed_cost::Float64
    variable_values::Dict{String, Float64}
end

# Define conversion method
Base.convert(::Type{PlanningSolution}, nt::NamedTuple) = PlanningSolution(nt.fixed_cost, nt.values)

struct BendersResults
    planning_problem::Model
    planning_solution::PlanningSolution
    subop_sol::Dict{Any, Any}
    LB_hist::Vector{Float64}
    UB_hist::Vector{Float64}
    cpu_time::Vector{Float64}
    planning_sol_hist::Matrix{Float64}
    op_subproblem::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray}
end

# Define constructor
# BendersResults(nt::NamedTuple) = convert(BendersResults, nt)
BendersResults(nt::NamedTuple, 
    op_subproblem::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray}
) = BendersResults(nt.planning_problem, 
    nt.planning_sol, 
    nt.subop_sol,
    nt.LB_hist, 
    nt.UB_hist, 
    nt.cpu_time, 
    nt.planning_sol_hist,
    op_subproblem
)