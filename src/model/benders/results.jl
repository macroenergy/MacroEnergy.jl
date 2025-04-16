struct BendersResults
    planning_problem::Model
    planning_sol::NamedTuple
    LB_hist::Vector{Float64}
    UB_hist::Vector{Float64}
    cpu_time::Vector{Float64}
    sol_hist::Matrix{Float64}
end

# Define conversion method
Base.convert(::Type{BendersResults}, nt::NamedTuple) = BendersResults(nt.planning_problem, nt.planning_sol, nt.LB_hist, nt.UB_hist, nt.cpu_time, nt.sol_hist)

# Define constructor
BendersResults(nt::NamedTuple) = convert(BendersResults, nt)
