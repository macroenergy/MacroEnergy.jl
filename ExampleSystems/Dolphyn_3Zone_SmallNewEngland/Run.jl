# using Pkg
# ### Activate environment where Macro package is
# Pkg.activate(dirname(dirname(@__DIR__)))

using Dolphyn
using Revise

settings_path = joinpath(@__DIR__, "Settings")

inputs_path = @__DIR__

setup = load_settings(settings_path)
### Deactivate scaling in Dolphyn so that all units conversions work properly. Scaling will be done in MACRO later on.
setup["ParameterScale"] = 0; 

global_logger = setup_logging(setup)

OPTIMIZER = configure_solver(setup["Solver"], settings_path)

inputs = load_inputs(setup, inputs_path)

# ### Load H2 inputs if modeling the hydrogen supply chain
if setup["ModelH2"] == 1
    inputs = load_h2_inputs(inputs, setup, inputs_path)
end

# dolphyn_model = Dolphyn.generate_model(setup, inputs, OPTIMIZER)
# optimize!(dolphyn_model)

using Macro, BenchmarkTools

macro_inputs, macro_settings = Macro.dolphyn_to_macro(inputs,settings_path);

model = Macro.generate_model(macro_inputs);

# b_model_building = @benchmark Macro.generate_model($macro_inputs);

using JuMP, Gurobi
set_optimizer(model,Gurobi.Optimizer)
optimize!(model)

# total_capacity_ngcc = sum(value(Macro.capacity(macro_inputs.transformations[NaturalGasPower][i].TEdges[:E])) for i in 1:3)
# total_capacity_smr = sum(value(Macro.capacity(macro_inputs.transformations[NaturalGasHydrogen][i].TEdges[:H2])) for i in 1:3)
# total_capacity_smr_ccs = sum(value(Macro.capacity(macro_inputs.transformations[NaturalGasHydrogen][i].TEdges[:H2])) for i in 4:6)


# compute_conflict!(model)
# list_of_conflicting_constraints = ConstraintRef[];
# for (F, S) in list_of_constraint_types(model)
#     for con in all_constraints(model, F, S)
#         if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
#             push!(list_of_conflicting_constraints, con)
#         end
#     end
# end
# display(list_of_conflicting_constraints)

println()