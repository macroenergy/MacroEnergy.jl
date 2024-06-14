using Pkg
Pkg.activate((dirname(@__DIR__)))

using Revise
using Macro
using Gurobi
using CSV
using DataFrames

T = 10*24;
macro_settings = (Commodities = Dict(Electricity=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24),
                                    Hydrogen=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24),
                                    NaturalGas=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24),
                                    CO2=>Dict(:HoursPerTimeStep=>1,:HoursPerSubperiod=>24)),
                PeriodLength = T,
                NumberOfPeriods=1);

                
hours_per_timestep(c) = macro_settings.Commodities[c][:HoursPerTimeStep];
hours_per_subperiod(c) = macro_settings.Commodities[c][:HoursPerSubperiod]
time_interval(c)= 1:hours_per_timestep(c):macro_settings.NumberOfPeriods*macro_settings.PeriodLength

subperiods(c) = collect(Iterators.partition(time_interval(c), Int(hours_per_subperiod(c) / hours_per_timestep(c))),)


H2_MWh = 33.33 # MWh per tonne of H2
NG_MWh = 0.29307107 # MWh per MMBTU of NG

df = CSV.read(dirname(@__DIR__)*"/tutorials/time_series_data.csv",DataFrame)

electricity_demand = df[1:T,:Electricity_Demand_MW]; # MWh
solar_capacity_factor = df[1:T,:Solar_Capacity_Factor]; # factor between 0 and 1
ng_fuel_price = df[1:T,:NG_Price]/NG_MWh; # $/MWh of natural gas
h2_demand = H2_MWh*df[1:T,:H2_Demand_tonne] # MWh of hydrogen

solar_inv_cost = 85300; # $/MW
solar_fom_cost = 18760.0; # $/MW

battery_inv_cost = 19584.0; #$/MW
battery_fom_cost = 4895; # $/MW
battery_fom_cost = 0.15; #$/MW
battery_inv_cost_storage = 22494.0; #$/MWh
battery_fom_cost_storage = 5622; #$/MWh
battery_vom_cost_storage = 0.15; #$/MWh
battery_min_duration = 1;
battery_max_duration = 10;
battery_eff_up = 0.92;
battery_eff_down = 0.92;

ngcc_inv_cost = 65400;# $/MW
ngcc_fom_cost = 10287.0;# $/MW
ngcc_vom_cost = 3.55; #$/MW
ngcc_capsize = 250.0;
ngcc_ramp_up = 0.64;
ngcc_ramp_down = 0.64;
ngcc_min_flow = 0.468;
ngcc_heatrate = 7.43*NG_MWh; # MWh of natural gas / MWh of electricity
ngcc_fuel_CO2 = 0.05306/NG_MWh; # Tons of CO2 / MWh of natural gas

electrolyzer_capsize = 2*H2_MWh # MWh of H2
electrolyzer_efficiency = 1/(45/H2_MWh) # MWh of H2 / MWh of electricity
electrolyzer_inv_cost = 2033333/H2_MWh # $/MWh of H2
electrolyzer_fom_cost = 30500/H2_MWh # $/MWh of H2
electrolyzer_vom_cost = 0.0;

e_node = Node{Electricity}(;
    id = Symbol("E_node"),
    demand = electricity_demand,
    time_interval = time_interval(Electricity),
    subperiods = subperiods(Electricity),
    max_nsd = [0.0],
    price_nsd = [0.0],
    constraints = [Macro.DemandBalanceConstraint()]
)

w_node = Node{Water}(;
    id = Symbol("W_node"),
    demand = electricity_demand,
    time_interval = time_interval(Water), #set to hourly for now 
    subperiods = subperiods(Water),
    max_nsd = [0.0],
    price_nsd = [0.0],
    constraints = [Macro.DemandBalanceConstraint()]
)

solar_pv = Transformation{SolarPV}(;
id = :solar_pv,
time_interval = time_interval(Electricity),
)

solar_pv.TEdges[:E] = TEdge{Electricity}(;
id = :E,
node = e_node,
transformation = solar_pv,
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
capacity_factor = solar_capacity_factor,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
existing_capacity = 0.0,
investment_cost = solar_inv_cost,
fixed_om_cost = solar_fom_cost,
constraints = [Macro.CapacityConstraint()]
)

battery = Transformation{Storage}(;
id = :battery,
stoichiometry_balance_names = [:storage],
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
can_expand = true,
can_retire = false,
existing_capacity_storage = 0.0,
investment_cost_storage = battery_inv_cost_storage,
fixed_om_cost_storage = battery_fom_cost_storage,
min_duration = battery_min_duration ,
max_duration = battery_max_duration ,
constraints = [Macro.StorageCapacityConstraint(),Macro.StoichiometryBalanceConstraint()],
discharge_capacity_edge = :discharge
)

battery.TEdges[:discharge] = TEdge{Electricity}(;
id = :discharge,
node = e_node,
transformation = battery,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
existing_capacity = 0.0,
investment_cost = battery_inv_cost,
fixed_om_cost = battery_fom_cost,
variable_om_cost = battery_fom_cost,
st_coeff = Dict(:storage=>1/battery_eff_down),
constraints = [Macro.CapacityConstraint()]
)

battery.TEdges[:charge] = TEdge{Electricity}(;
id = :charge,
node = e_node,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
transformation = battery,
direction = :input,
has_planning_variables = false,
can_expand = false,
can_retire = false,
variable_om_cost = battery_fom_cost,
st_coeff = Dict(:storage=>battery_eff_up),
)

hydrostor = Transformation{Storage}(;
id = :hydrostor,
stoichiometry_balance_names = [:storage],
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
can_expand = true,
can_retire = false,
existing_capacity_storage = 0.0,
investment_cost_storage = battery_inv_cost_storage,
fixed_om_cost_storage = battery_fom_cost_storage,
min_duration = battery_min_duration ,
max_duration = battery_max_duration ,
constraints = [Macro.StorageCapacityConstraint(),Macro.StoichiometryBalanceConstraint()],
discharge_capacity_edge = :discharge
)

hydrostor.TEdges[:discharge] = TEdge{Water}(;
id = :discharge,
node = e_node,
transformation = battery,
time_interval = time_interval(Water),
subperiods = subperiods(Water),
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
existing_capacity = 0.0,
investment_cost = battery_inv_cost,
fixed_om_cost = battery_fom_cost,
variable_om_cost = battery_fom_cost,
st_coeff = Dict(:storage=>1/battery_eff_down),
constraints = [Macro.CapacityConstraint()]
)

hydrostor.TEdges[:charge] = TEdge{Water}(;
id = :charge,
node = e_node,
time_interval = time_interval(Water),
subperiods = subperiods(Water),
transformation = battery,
direction = :input,
has_planning_variables = false,
can_expand = false,
can_retire = false,
variable_om_cost = battery_fom_cost,
st_coeff = Dict(:storage=>battery_eff_up),
)

hydrostor.TEdges[:discharge] = TEdge{Electricity}(;
id = :discharge,
node = e_node,
transformation = battery,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
existing_capacity = 0.0,
investment_cost = battery_inv_cost,
fixed_om_cost = battery_fom_cost,
variable_om_cost = battery_fom_cost,
st_coeff = Dict(:storage=>1/battery_eff_down),
constraints = [Macro.CapacityConstraint()]
)

hydrostor.TEdges[:charge] = TEdge{Electricity}(;
id = :charge,
node = e_node,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
transformation = battery,
direction = :input,
has_planning_variables = false,
can_expand = false,
can_retire = false,
variable_om_cost = battery_fom_cost,
st_coeff = Dict(:storage=>battery_eff_up),
)

ng_node = Node{NaturalGas}(;
    id = Symbol("NG_node"),
    time_interval = time_interval(NaturalGas),
    subperiods = subperiods(NaturalGas),
    demand = zeros(length(time_interval(NaturalGas))),
     #### Note that this node does not have a demand balance because we are modeling exogenous inflow of NG
)

co2_node = Node{CO2}(;
id = Symbol("CO2_node"),
time_interval = time_interval(CO2),
subperiods = subperiods(CO2),
demand = zeros(length(time_interval(CO2))),
max_nsd = [0.0],
price_nsd = [0.0],
)

ngcc = Transformation{NaturalGasPower}(;
id = :NGCC,
time_interval = time_interval(Electricity),
stoichiometry_balance_names = [:energy,:emissions],
constraints = [Macro.StoichiometryBalanceConstraint()]
)

ngcc.TEdges[:E] = TEdgeWithUC{Electricity}(;
id = :E,
node = e_node,
transformation = ngcc,
direction = :output,
has_planning_variables = true,
can_expand = true,
can_retire = false,
capacity_size = ngcc_capsize,
time_interval = time_interval(Electricity),
subperiods = subperiods(Electricity),
st_coeff = Dict(:energy=>ngcc_heatrate,:emissions=>0.0),
existing_capacity = 0.0,
investment_cost = ngcc_inv_cost,
fixed_om_cost = ngcc_fom_cost,
variable_om_cost =ngcc_vom_cost,
ramp_up_fraction = ngcc_ramp_up,
ramp_down_fraction = ngcc_ramp_down,
min_flow_fraction = ngcc_min_flow,
min_up_time = 7,
min_down_time = 10,
start_cost = 91,
start_fuel = 2*NG_MWh,
start_fuel_stoichiometry_name = :energy,
constraints = [ Macro.CapacityConstraint(),
                Macro.RampingLimitConstraint(),
                Macro.MinFlowConstraint(),
                Macro.MinUpTimeConstraint(),
                Macro.MinDownTimeConstraint(),
            ]
)

ngcc.TEdges[:NG] = TEdge{NaturalGas}(;
id =  :NG,
node = ng_node,
transformation = ngcc,
direction = :input,
has_planning_variables = false,
time_interval = time_interval(NaturalGas),
subperiods = subperiods(NaturalGas),
st_coeff = Dict(:energy=>1.0,:emissions=>ngcc_fuel_CO2),
price = ng_fuel_price,
)

ngcc.TEdges[:CO2] = TEdge{CO2}(;
    id = :CO2,
    node = co2_node,
    transformation = ngcc,
    direction = :output,
    has_planning_variables = false,
    time_interval = time_interval(CO2),
    subperiods = subperiods(CO2),
    st_coeff = Dict(:energy=>0.0,:emissions=>1.0)
    )

system = [e_node;ng_node;co2_node;solar_pv;battery;ngcc]

model = Macro.Model()
Macro.@variable(model, vREF == 1)
Macro.@expression(model, eFixedCost, 0 * model[:vREF])
Macro.@expression(model, eVariableCost, 0 * model[:vREF])
Macro.add_planning_variables!.(system, Ref(model))
Macro.add_operation_variables!.(system, Ref(model))
Macro.add_all_model_constraints!.(system, Ref(model))
Macro.@objective(model,Min,model[:eFixedCost] + model[:eVariableCost])
Macro.set_optimizer(model,Gurobi.Optimizer)

Macro.optimize!(model)
base_cost = Macro.objective_value(model);
base_emissions  = Macro.value(sum(Macro.net_balance(co2_node)[t] for t in time_interval(CO2)))

merge!(co2_node.rhs_policy,Dict(Macro.CO2CapConstraint => 0.5*base_emissions))
append!(co2_node.constraints,[Macro.CO2CapConstraint()])
Macro.add_model_constraint!(co2_node.constraints[1],co2_node,model)

Macro.optimize!(model)

capped_emissions = Macro.value(sum(Macro.net_balance(co2_node)[t] for t in time_interval(CO2)))
capped_emissions_cost = Macro.objective_value(model);
println("Base emissions: $base_emissions, with system cost: $base_cost")
println("Capped emissions: $capped_emissions, with system cost: $capped_emissions_cost")