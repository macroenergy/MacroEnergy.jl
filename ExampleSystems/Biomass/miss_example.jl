using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Revise
using Gurobi
using CSV
using DataFrames

macro_settings = (Commodities = Dict(Hydrogen=>Dict(:HoursPerTimeStep=>1,
                                                    :HoursPerSubperiod=>168,
                                                    :WeightsPerSubperiod=>168*ones(52)),
                                    CO2=>Dict(:HoursPerTimeStep=>8736,
                                            :HoursPerSubperiod=>8736,
                                            :WeightsPerSubperiod=>[8736]),
                                    Biomass=>Dict(:HoursPerTimeStep=>8736,
                                    :HoursPerSubperiod=>8736,
                                    :WeightsPerSubperiod=>[8736])),
                PeriodLength = 8736);

all_timedata = Macro.create_time_data(macro_settings);

### Note: H2 is in MWh, Biomass is in tonnes, CO2 is in tonnes. Costs and prices are in $.

H2_MWh = 33.33 # MWh per tonne of H2
NG_MWh = 0.29307107 # MWh per MMBTU of NG

ts = CSV.read(dirname(dirname(@__DIR__))*"/tutorials/time_series_data.csv",DataFrame)

#### Gasification to Hydrogen
## Biomass (MWh) -> H2 (MWh) + CO2 (tons)
## H2 = BtoH2_eff * Biomass 
## CO2Captured=  CDR_potential * Biomass
BtoH2_eff = 0.63; ### {MWh of H2}/{MWh of biomass} ## Fake numbers, need to be converted to right units
CDR_potential = 0.326; ## {ton of CO2 captured}/{MWh of biomass} Fake numbers, need to be converted to right units

node_biomass = Node{Biomass}(;
id = Symbol("Bnode"),
timedata = all_timedata[Biomass],
#### Note that this node does not have a demand balance because we are modeling exogenous inflow of biomass
demand = Dict(t => 0.0 for t in all_timedata[Biomass].timesteps),
)

node_h2 = Node{Hydrogen}(;
id = Symbol("H2node"),
timedata = all_timedata[Hydrogen],
demand = Dict(t => 1.0 for t in all_timedata[Hydrogen].timesteps),
constraints = [Macro.DemandBalanceConstraint()]
)

captured_co2 = Node{CO2}(;
id = Symbol("StorCO2"),
timedata = all_timedata[CO2],
demand = zeros(length(all_timedata[CO2].timesteps)),
#### Note that this node does not have a demand balance because we are modeling a sink of captured CO2, that does not carry a demand balance
)

biomass_to_h2_size1 = Transformation{GasificationH2}(;
id = :BtoH2,
timedata = all_timedata[Biomass],
stoichiometry_balance_names = [:h2production,:carbon_removal],
constraints = [Macro.StoichiometryBalanceConstraint()]
)


biomass_to_h2_size1.TEdges[:B] = TEdge{Biomass}(;
id = :B,
node = node_biomass,
direction = :input,
transformation = biomass_to_h2_size1,
has_planning_variables = true,
can_expand = true,
can_retire = false,
capacity_size = 100,
timedata = all_timedata[Biomass],
existing_capacity = 0.0,
capacity_factor = Dict(t => 0.9 for t in all_timedata[Biomass].timesteps),
investment_cost =  295007582.79, ### $/(MW/year) #Check that this is correct from Input/Output Efficiency spreadsheet
fixed_om_cost = 14750379.14, ### $/(MW/year) #Check that this is correct from Input/Output Efficiency
variable_om_cost = 2603007 , ### $/(MWh/year) #Check that this is correct from Input/Output Efficiency
##### Example of definition of supply curve: 
### Segments = [s1,s2,s3]
### Prices = [p1,p2,p3]
### Total Supply = Q, assuming s1 < Q  < s2, then:
### the total cost paid for the supply is: s1*p1 + (Q-s1)*p2
supply_curve = Dict(:segments=>[1e3;1e6;1e9],:prices=>[1e2;1e3;1e4]),
st_coeff = Dict(:h2production => BtoH2_eff,:carbon_removal=>CDR_potential), 
constraints = [Macro.CapacityConstraint()]
)

biomass_to_h2_size1.TEdges[:CO2Captured] = TEdge{CO2}(;
id = :CO2Captured,
node = captured_co2,
direction = :output,
transformation = biomass_to_h2_size1,
has_planning_variables = false,
capacity_size = 1.0,
timedata = all_timedata[CO2],
existing_capacity = 0.0,
st_coeff = Dict(:h2production => 0.0,:carbon_removal=>1.0),
)

biomass_to_h2_size1.TEdges[:H2] = TEdge{Hydrogen}(;
id = :H2,
node = node_h2,
direction = :output,
transformation = biomass_to_h2_size1,
has_planning_variables = false,
capacity_size = 1.0,
timedata = all_timedata[Hydrogen],
existing_capacity = 0.0,
st_coeff = Dict(:h2production => 1.0,:carbon_removal=>0.0),
)


system = [node_biomass;node_h2;captured_co2;biomass_to_h2_size1];

model = Macro.Model()
Macro.@variable(model, vREF == 1)
Macro.@expression(model, eFixedCost, 0 * model[:vREF])
Macro.@expression(model, eVariableCost, 0 * model[:vREF])
Macro.add_planning_variables!.(system, Ref(model))
Macro.add_operation_variables!.(system, Ref(model))
Macro.add_all_model_constraints!.(system, Ref(model))
Macro.@objective(model,Min,model[:eFixedCost] + model[:eVariableCost])

println("The H2 production stoichiometry balance is:")
println("")
println(biomass_to_h2_size1.constraints[1].constraint_ref[:h2production,1])
println("")
println("The carbon removal stoichiometry balance is:")
println("")
println(biomass_to_h2_size1.constraints[1].constraint_ref[:carbon_removal,1])
println("")
println("The capacity factor constraint for the gassification process is:")
println("")
println(biomass_to_h2_size1.TEdges[:B].constraints[1].constraint_ref[1])
println("")
println("**** Now we solve the model:*****")
Macro.set_optimizer(model,Gurobi.Optimizer)
Macro.optimize!(model)


println("The model has built a facility with capacity = $(Macro.value(Macro.capacity(biomass_to_h2_size1.TEdges[:B]))) BiomassMW/year")