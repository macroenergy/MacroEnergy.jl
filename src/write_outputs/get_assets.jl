function get_asset_by_id(system::System, id_name::Symbol)
    for asset in system.assets
        if id(asset) == id_name
            return asset
        end
    end
end