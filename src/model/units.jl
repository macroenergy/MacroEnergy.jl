const DEFAULT_UNITS = Dict{Symbol,Symbol}(
    :Electricity => :MWh,
    :Hydrogen => :MWh,
    :NaturalGas => :MWh,
    :Uranium => :MWh,
    :CO2 => :t,
    :CO2Captured => :t,
    :Biomass => :t,
    :LiquidFuels => :MWh,
)

function convert_power_to_energy_unit(unit::Symbol)::Symbol
    unit == :MWh && return :MW
    return unit
end

function unit(commodity::Symbol, f::Function)::Symbol
    unit = DEFAULT_UNITS[commodity]
    if any(f .== [capacity, new_capacity, retired_capacity])
        return convert_power_to_energy_unit(unit)
    elseif any(f .== [flow, non_served_demand, storage_level])
        return unit
    else
        @warn("Unit not supported.")
    end
end
unit(commodity::DataType, f::Function)::Symbol = unit(Symbol(commodity), f)