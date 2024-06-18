function load_fuel_data!(system_dir::AbstractString, assets::Dict{Symbol,AbstractAsset})
    fuel_dir = joinpath(system_dir, "fuel_data")
    fuel_data = load_all_ts(fuel_dir)
    
    co2_emission = load_co2_emission(fuel_dir)

    add_fuel_to_assets!(assets, fuel_data, co2_emission)

    return nothing
end

function load_co2_emission(fuel_dir::AbstractString)
    file = "co2_emission.json"
    co2_emission_data = JSON3.read(joinpath(fuel_dir, file))
    return co2_emission_data
end

function add_fuel_to_assets!(assets::Dict{Symbol,AbstractAsset}, fuel_data::Dict{Symbol,Vector{Float64}}, co2_emission::JSON3.Object)
    add_fuel_to_tedges!(tedges(assets), fuel_data, co2_emission)
    return nothing
end 

function add_fuel_to_tedges!(tedges::Dict{Symbol,T}, fuel_data::Dict{Symbol,Vector{Float64}}, co2_emission::JSON3.Object) where T<:AbstractTransformationEdge
    for (_, tedge) in tedges
        if tedge.price_header ∈ keys(fuel_data)
            tedge.price = fuel_data[tedge.price_header] / NG_MWh
        end
        if tedge.price_header ∈ keys(co2_emission)
            tedge.st_coeff[:emissions] = co2_emission[tedge.price_header] / NG_MWh
        end
    end
    return nothing
end

