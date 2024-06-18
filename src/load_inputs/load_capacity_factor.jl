function load_capacity_factor!(assets::Dict{Symbol,AbstractAsset}, asset_dir::AbstractString)
    cf_dir = joinpath(asset_dir, "capacity_factor_data")
    files = filter(x -> endswith(x, ".csv"), readdir(cf_dir))

    assets_cf = Dict{Symbol,Vector{Float64}}()
    for file in files
        merge!(assets_cf, load_timeseries(joinpath(cf_dir, file)))
    end

    for (asset_id, asset) in assets
        if asset_id in keys(assets_cf)
            add_capacity_factor!(asset, assets_cf[asset_id])
        end
    end
    return nothing
end