const BalanceCoeff = Union{Float64,Vector{Float64}}

function normalize_balance_coeff(coeff::Number)
    return Float64(coeff)
end

function normalize_balance_coeff(coeff::AbstractVector{<:Number})
    normalized = Float64.(collect(coeff))
    return length(normalized) == 1 ? only(normalized) : normalized
end

struct BalanceTerm
    obj::Any
    var::Symbol
    coeff::BalanceCoeff
    lag::Int
end

BalanceTerm(obj, var::Symbol = :flow, coeff = 1.0, lag::Int = 0) =
    BalanceTerm(obj, var, normalize_balance_coeff(coeff), lag)

function BalanceTerm(; obj, var::Symbol = :flow, coeff = 1.0, lag::Int = 0)
    return BalanceTerm(obj, var, normalize_balance_coeff(coeff), lag)
end

Base.@kwdef struct BalanceData
    sense::Symbol = :eq
    terms::Vector{BalanceTerm} = BalanceTerm[]
    constant::Float64 = 0.0
end
