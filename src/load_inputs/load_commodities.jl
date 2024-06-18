function load_commodities_json(data_dir::AbstractString)
    # get the list of all commodities available
    macro_commodities = commodity_types()

    # read in the list of commodities from the data directory
    file = "commodities.json"
    isfile(joinpath(data_dir, file)) || error("File not found: $file")
    data = JSON3.read(joinpath(data_dir, file))

    # make sure the commodities are valid
    @assert haskey(data, :commodities)
    commodities = Symbol.(data[:commodities])

    validate_commodities(commodities)

    # return a dictionary of commodities Dict{Symbol, DataType}
    commodities = Symbol.(data[:commodities])
    filter!(((key,_),) -> key in commodities, macro_commodities)
    return macro_commodities
end

function validate_commodities(commodities, macro_commodities::Dict{Symbol,DataType}=commodity_types(Macro))
    if any(commodity -> commodity ∉ keys(macro_commodities), commodities)
        error("Unknown commodities: $(setdiff(commodities, keys(macro_commodities)))")
    end
    return nothing
end
