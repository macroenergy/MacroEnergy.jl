using CSV, DataFrames, JSON3


demand_dir = "ExampleSystems/three_zones_macro/system/demand_data/"
filename = "Demand_data.csv"

output_dir = "ExampleSystems/three_zones_macro/system/demand_data/"

demand_df = CSV.read(joinpath(demand_dir, filename), DataFrame)
translate_genx_demand(demand_df, output_dir)


function translate_genx_demand(demand_df::DataFrame, output_dir::AbstractString)
    voll_data_cols = ["Voll"]
    nsd_data_cols = ["Demand_Segment", "Cost_of_Demand_Curtailment_per_MW", "Max_Demand_Curtailment", "\$/MWh"]
    time_data_cols = ["Rep_Periods", "Timesteps_per_Rep_Period", "Sub_Weights"]

    create_nsd_data(demand_df, nsd_data_cols, output_dir)
    create_demand_data(demand_df, vcat(voll_data_cols, nsd_data_cols, time_data_cols), output_dir)

    return nothing

end

function create_nsd_data(demand_df::DataFrame, selected_columns::Vector{String}, output_dir::AbstractString)
    new_columns = [:demand_segment, :cost_of_demand_curtailment_per_mw, :max_demand_curtailment, :cost_of_electricity]
    demand_segment_df = dropmissing(select(demand_df, selected_columns))

    demand_segment_array = [Dict{Symbol,Float64}() for _ in 1:nrow(demand_segment_df)]
    column_names = propertynames(demand_segment_df)

    for (i, demand_segment) in enumerate(demand_segment_array)
        for (j, col) in enumerate(column_names)
            demand_segment[new_columns[j]] = demand_segment_df[i, col]
        end
    end

    nsd_data = Dict{Symbol, Dict}(
        :Electricity => Dict{Symbol,Any}(
            :voll => demand_df[1, :Voll],
            :nsd_data => demand_segment_array
        )
    )
    
    open(joinpath(output_dir, "nsd_data.json"), "w") do io
        JSON3.pretty(io, nsd_data)
    end
end

function create_demand_data(demand_df::DataFrame, remove_columns::Vector{String}, output_dir::AbstractString)
    demand_df = select!(demand_df, Not(remove_columns))
    open(joinpath(output_dir, "electricity_demand.csv"), "w") do io
        CSV.write(io, demand_df)
    end
end
    