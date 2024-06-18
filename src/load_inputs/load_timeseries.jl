function load_timeseries(filepath::AbstractString)

    isfile(filepath) || return Dict()

    df_timeseries = load_dataframe(filepath)

    time_index = popat_col!(df_timeseries, :Time_Index)

    validate_timeseries(time_index)

    time_series = Dict{Symbol,Vector{Float64}}()
    for col in propertynames(df_timeseries)
        time_series[col] = df_timeseries[!, col]
    end
    return time_series
end


#TODO: implement a validation function for timeseries
function validate_timeseries(df::Vector)
    return nothing
end


# pop column from dataframe and return it
function popat_col!(df::DataFrame, col::Symbol)
    @assert (col ∈ propertynames(df))
    col_values = df[!, col]
    select!(df, Not(col))
    return col_values
end
