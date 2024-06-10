using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Revise
using Gurobi
using CSV
using DataFrames

macro_settings = (Commodities = Dict(Hydrogen=>Dict(:HoursPerTimeStep=>24,
                                                    :HoursPerSubperiod=>24,
                                                    :WeightsPerSubperiod=>ones(10)),
                                    CO2=>Dict(:HoursPerTimeStep=>24,
                                            :HoursPerSubperiod=>24,
                                            :WeightsPerSubperiod=>ones(10)),
                                    Biomass=>Dict(:HoursPerTimeStep=>24,
                                    :HoursPerSubperiod=>24,
                                    :WeightsPerSubperiod=>ones(10))),
                PeriodLength =10*24);


all_timedata = Macro.create_time_data(macro_settings);

### Note: H2 is in MWh, Biomass is in tonnes, CO2 is in tonnes. Costs and prices are in $.

H2_MWh = 33.33 # MWh per tonne of H2
NG_MWh = 0.29307107 # MWh per MMBTU of NG

ts = CSV.read(dirname(dirname(@__DIR__))*"/tutorials/time_series_data.csv",DataFrame)

#### Gasification to Hydrogen
## Biomass + CO2 -> H2
## H2 = BtoH2_eff * Biomass 
## Removed CO2 = CDR_potential * Biomass =  (CDR_potential/BtoH2_eff)*H2

BtoH2_eff = 0.8; ### {MWh of H2}/{ton of biomass} ## Fake numbers, need to be converted to right units
CDR_potential = 1; ## {ton of CO2 captured}{ton of biomass} Fake numbers, need to be converted to right units

h2_demand = H2_MWh*[sum(ts.H2_Demand_tonne[24*(i-1)+i:24*i]) for i in 1:10] # MWh of hydrogen (daily demand)

node_biomass = Node{Biomass}(;
id = Symbol("Bnode"),
timedata = all_timedata[Biomass],
#### Note that this node does not have a demand balance because we are modeling exogenous inflow of biomass
demand = Dict(t => 0.0 for t in all_timedata[Biomass].time_interval),
)

node_h2 = Node{Hydrogen}(;
id = Symbol("H2node"),
timedata = all_timedata[Hydrogen],
demand = Dict(t => h2_demand[findfirst(all_timedata[Biomass].time_interval.==t)] for t in all_timedata[Hydrogen].time_interval),
constraints = [Macro.DemandBalanceConstraint()]
)

atmosphere_co2 = Node{CO2}(;
id = Symbol("AtmCO2"),
timedata = all_timedata[CO2],
demand = Dict(t => 0.0 for t in all_timedata[CO2].time_interval),
#### Note that this node does not have a demand balance because we are modeling exogenous inflow of co2 (we do not model processes that produce CO2)
)

# captured_co2 = Node{CO2Captured}(;
# id = Symbol("StorCO2"),
# timedata = all_timedata[CO2Captured],
# demand = zeros(length(all_timedata[CO2Captured].time_interval)),
# #### Note that this node does not have a demand balance because we are modeling a sink of CO2, that does not carry a demand balance
# )

biomass_to_h2 = Transformation{GasificationH2}(;
id = :BtoH2,
timedata = all_timedata[Hydrogen],
stoichiometry_balance_names = [:h2production,:carbon_removal],
constraints = [Macro.StoichiometryBalanceConstraint()]
)

biomass_to_h2.TEdges[:B] = TEdge{Biomass}(;
id = :B,
node = node_biomass,
direction = :input,
transformation = biomass_to_h2,
has_planning_variables = true,
can_expand = true,
can_retire = false,
capacity_size = 1.0,
timedata = all_timedata[Biomass],
existing_capacity = 0.0,
investment_cost =  763602317.52/2000, ### $/(ton/day) #Check that this is correct from Input/Output Efficiency spreadsheet
fixed_om_cost = 38180115.88/2000/365, ### $/(ton/day) #Check that this is correct from Input/Output Efficiency
variable_om_cost = 11930447.22/2000/365, ### $/(ton/day) #Check that this is correct from Input/Output Efficiency
price = Dict(t => 39420000/2000/365 for t in all_timedata[Biomass].time_interval),
st_coeff = Dict(:h2production => BtoH2_eff,:carbon_removal=>0.0), 
constraints = [Macro.CapacityConstraint()]
)

biomass_to_h2.TEdges[:CO2] = TEdge{CO2}(;
id = :CO2,
node = atmosphere_co2,
direction = :input,
transformation = biomass_to_h2,
has_planning_variables = false,
capacity_size = 1.0,
timedata = all_timedata[CO2],
existing_capacity = 0.0,
variable_om_cost = 68.06, ### $/tonCO2
st_coeff = Dict(:h2production => 0.0,:carbon_removal=>1.0),
)


biomass_to_h2.TEdges[:H2] = TEdge{Hydrogen}(;
id = :H2,
node = node_h2,
direction = :output,
transformation = biomass_to_h2,
has_planning_variables = false,
capacity_size = 1.0,
timedata = all_timedata[Hydrogen],
existing_capacity = 0.0,
st_coeff = Dict(:h2production => 1.0,:carbon_removal=>CDR_potential/BtoH2_eff),
)

system = [node_biomass;node_h2;atmosphere_co2;biomass_to_h2];

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

println("The model has built a facility with capacity = $(Macro.value(Macro.capacity(biomass_to_h2.TEdges[:B]))) ton/day")