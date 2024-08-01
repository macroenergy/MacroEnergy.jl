function load_storage(
    filepath::AbstractString,
    nodes::Dict{Symbol,Node},
    commodity,
    time_interval::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)

    df_storage = load_dataframe(filepath)

    adjust_cols_names!(df_storage)
    adjust_cols_types!(df_storage)

    storage_id = Symbol.(popat_col!(df_storage, :id))
    node_id = Symbol.(popat_col!(df_storage, :node))
    storage_type = Symbol.(popat_col!(df_storage, :type))

    num_sym_storage = count(storage_type .== :Symmetric)
    num_asym_storage = count(storage_type .== :Asymmetric)

    sym_storage = Vector{SymmetricStorage}(undef, num_sym_storage)
    asym_storage = Vector{AsymmetricStorage}(undef, num_asym_storage)

    # loop over dataframe rows and create a storage for each row
    for (i, row) in enumerate(eachrow(df_storage[storage_type.==:Symmetric, :]))
        sym_storage[i] = SymmetricStorage{commodity}(;
            id = storage_id[i],
            node = nodes[node_id[i]],
            time_interval = time_interval,
            subperiods = subperiods,
            row...,
        )
    end
    for (i, row) in enumerate(eachrow(df_storage[storage_type.==:Asymmetric, :]))
        asym_storage[i] = AsymmetricStorage{commodity}(;
            id = storage_id[i],
            node = nodes[node_id[i]],
            time_interval = time_interval,
            subperiods = subperiods,
            row...,
        )
    end

    # output: array of asym and sym storage
    return Storage(sym_storage, asym_storage)
end
