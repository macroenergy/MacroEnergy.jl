@inline function total_years(period_lengths::Vector{Int})
    return sum(period_lengths; init=0)
end

@inline function years_remaining(period_idx::Int, period_lengths::Vector{Int})
    total = 0
    for i in period_idx:lastindex(period_lengths)
        total += period_lengths[i]
    end
    return total
end

function period_start_years(period_lengths::Vector{Int}, n::Int)
    if isempty(period_lengths)
        return 0
    end
    result = 0
    @inbounds for i in 2:n
        result += period_lengths[i-1]
    end
    return result
end

function period_start_years(period_lengths::Vector{Int})
    if isempty(period_lengths)
        return [0]
    end
    n = length(period_lengths)
    result = Vector{Int}(undef, n)
    result[1] = 0
    @inbounds for i in 2:n
        result[i] = result[i-1] + period_lengths[i-1]
    end
    return result
end

@inline function present_value_factor(discount_rate::Float64, total_years::Int)
    # This assumes we'll check that total_years and discount rate are non-negative beforehand
    if discount_rate == 0.0
        return 1.0
    end
    return 1 / ( (1 + discount_rate) ^ total_years)
end

function present_value_factor(discount_rate::Float64, period_lengths::Vector{Int})
    return present_value_factor.(discount_rate, period_start_years(period_lengths))
end

@inline function present_value_annuity_factor(discount_rate::Float64, total_years::Int)
    # This assumes we'll check that total_years and discount rate are non-negative beforehand
    # sum(1 / (1 + discount_rate)^i) for i 1:N = (1 - (1 + discount_rate)^-N) / discount_rate = 1 / CRF
    if discount_rate == 0.0
        return total_years
    end
    return  (1 - (1 + discount_rate) ^ (-total_years)) / discount_rate
end

@inline function capital_recovery_factor(discount_rate::Float64, total_years::Int)
    # This assumes we'll check that total_years and discount rate are non-negative beforehand
    if discount_rate == 0.0
        return 1.0 / total_years
    end
    return discount_rate / (1 - (1 + discount_rate) ^ (-total_years))
end