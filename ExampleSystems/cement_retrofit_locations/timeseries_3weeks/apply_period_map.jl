using Pkg
Pkg.activate(dirname(dirname(dirname(@__DIR__))))
using MacroEnergy
using CSV
using DataFrames
using YAML
using JSON3

period_map = CSV.read(joinpath(@__DIR__, "Period_map.csv"),DataFrame)
path_to_full_timeseries = joinpath(dirname(@__DIR__), "timeseries_full_year/")

rep_periods = unique(sort(period_map,3).Rep_Period);

tdr_settings = YAML.load_file(joinpath(@__DIR__, "time_domain_reduction_settings.yml"))
timesteps_per_rep_period = tdr_settings["TimestepsPerRepPeriod"]

weights_unscaled = [length(findall(period_map[:,:Rep_Period].==p)) for p in rep_periods]
weight_total = tdr_settings["WeightTotal"]

weights = weight_total*weights_unscaled/sum(weights_unscaled)

demand_full = CSV.read(joinpath(path_to_full_timeseries, "demand.csv"),DataFrame)
availability_full = CSV.read(joinpath(path_to_full_timeseries, "availability.csv"),DataFrame)
fuel_prices_full = CSV.read(joinpath(path_to_full_timeseries, "fuel_prices.csv"),DataFrame)

timesteps_to_collect = reduce(vcat,[collect((p-1)*timesteps_per_rep_period+1:p*timesteps_per_rep_period) for p in rep_periods])

demand = demand_full[timesteps_to_collect,:]
availability  = availability_full[timesteps_to_collect,:]
fuel_prices = fuel_prices_full[timesteps_to_collect,:]

demand.Time_Index = collect(1:length(rep_periods)*timesteps_per_rep_period)
availability.Time_Index = collect(1:length(rep_periods)*timesteps_per_rep_period)
fuel_prices.Time_Index = collect(1:length(rep_periods)*timesteps_per_rep_period)

CSV.write(joinpath(@__DIR__, "demand.csv"), demand)
CSV.write(joinpath(@__DIR__, "availability.csv"), availability)
CSV.write(joinpath(@__DIR__, "fuel_prices.csv"), fuel_prices)

timedata = copy(JSON3.read(joinpath(@__DIR__,"time_data.json")))
timedata[:PeriodLength] = length(rep_periods)*timesteps_per_rep_period;
for c in keys(timedata[:HoursPerSubperiod])
    timedata[:HoursPerSubperiod][c] = timesteps_per_rep_period
end
JSON3.write(joinpath(@__DIR__,"time_data.json"),timedata)

println("###### ###### ######")