macro AbstractVertexBaseAttributes()
    esc(quote
        id::Symbol
        timedata::TimeData
        balance_data::Dict{Symbol, Dict{Symbol, Float64}} = Dict{Symbol, Dict{Symbol, Float64}}()
        operation_expr::Dict = Dict()
        constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
    end)
end

get_id(v::AbstractVertex) = v.id;
balance_ids(v::AbstractVertex) = collect(keys(v.balance_data));
balance_data(v::AbstractVertex,i::Symbol) = v.balance_data[i];

get_balance(v::AbstractVertex,i::Symbol) = v.operation_expr[i];
get_balance(v::AbstractVertex,i::Symbol,t::Int64) = get_balance(v,i)[t];

all_constraints(v::AbstractVertex) = v.constraints;