Base.@kwdef struct SupplySegment
    price::Vector{Float64}
    min::Vector{Float64}
    max::Vector{Float64}
end

Base.:(==)(left::SupplySegment, right::SupplySegment) =
    left.price == right.price && left.min == right.min && left.max == right.max