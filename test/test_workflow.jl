module TestWorkflow

using Test
using HiGHS
using Pkg
using JuMP
try Pkg.add("Gurobi"); using Gurobi; catch e end
using CSV, DataFrames, JSON3
import MacroEnergy:
    System,
    AbstractEdge,
    Edge,
    EdgeWithUC,
    Node,
    Location,
    Transformation,
    AbstractStorage,
    Storage,
    TimeData,
    Commodity,
    AbstractAsset,
    AbstractTypeConstraint,
    load_system,
    load_case,
    read_file,
    generate_model,
    create_optimizer,
    set_optimizer,
    optimize!,
    objective_value,
    commodity_type,
    AssetId,
    VariableRef,
    get_optimal_capacity,
    get_optimal_new_capacity,
    get_optimal_retired_capacity,
    get_optimal_flow,
    create_discounted_cost_expressions!,
    compute_undiscounted_costs!,
    get_optimal_discounted_costs,
    get_optimal_undiscounted_costs,
    write_capacity,
    write_costs,
    write_undiscounted_costs,
    write_detailed_costs,
    get_detailed_costs,
    write_flow,
    write_curtailment,
    typesymbol


include("utilities.jl")
include("test_timedata.jl")
const test_path = joinpath(@__DIR__, "test_inputs")
const system_data_true_path = joinpath(@__DIR__, "test_inputs/system_data_true.json")
const optim = is_gurobi_available() ? Gurobi.Optimizer : HiGHS.Optimizer
const obj_true = 1.5512721762979626e11

function test_configure_settings(data::NamedTuple, data_true::T) where {T<:JSON3.Object}
    @test data.ConstraintScaling == data_true.ConstraintScaling
    return nothing
end

function test_load_commodities(
    commodities::Dict{Symbol,DataType},
    commodities_true::T,
) where {T<:JSON3.Array}
    commodities_true = Symbol.(commodities_true)
    @test length(commodities) == length(commodities_true)
    for (k, v) in commodities
        @test k in commodities_true
        @test Symbol(v) in commodities_true
    end
    return nothing
end

test_load(data, data_true) = @test data == data_true
test_load(data::AssetId, data_true::String) = @test data == Symbol(data_true)

function test_load(obj_in::Dict{DataType,Float64}, data_true::T) where {T<:JSON3.Object}
    @test length(obj_in) == length(data_true)
    for (k, v) in obj_in
        @test Symbol(k) in keys(data_true)
        @test obj_in[k] == data_true[Symbol(k)]
    end
    return nothing
end

function find_by_id(id::Symbol, data_true::AbstractVector)
    for instance in data_true
        true_id = string(instance[:instance_data][:id])
        if true_id == id
            return instance
        end
    end
    return nothing
end

function test_load(obj_in::Vector{<:T}, data_true::JSON3.Array) where T <: Union{Node, Location, AbstractAsset}
    @test length(obj_in) == length(data_true)
    for i = 1:length(obj_in)
            true_instance = find_by_id(obj_in[i].id, data_true)
            if true_instance === nothing
                test_load(obj_in[i], data_true[i])
            else
                test_load(obj_in[i], true_instance)
            end
    end
    return nothing
end

function test_load(obj_in::Vector, data_true::JSON3.Array)
    @test length(obj_in) == length(data_true)
    for i = 1:length(obj_in)
        test_load(obj_in[i], data_true[i])
    end
    return nothing
end

function test_load(
    obj_in::Vector{AbstractTypeConstraint},
    data_true::T,
) where {T<:JSON3.Object}
    @test length(obj_in) == length(data_true)
    for c in obj_in
        name = Symbol(typeof(c))
        if !(name in propertynames(data_true))
            println("Constraint $name not found in JSON file")
        end
        @test name in propertynames(data_true)
        @test data_true[name]   # check that the constraint is set to true in the JSON file
    end
    return nothing
end

function test_load(e_in::AbstractEdge{T}, e_true::S) where {T<:Commodity,S<:JSON3.Object}
    @test e_in.start_vertex.id == Symbol(e_true.start_vertex)
    @test e_in.end_vertex.id == Symbol(e_true.end_vertex)
    @test typesymbol(commodity_type(e_in.timedata)) == Symbol(e_true.timedata)
    @test e_in.unidirectional == get(e_true, :unidirectional, true)
    @test e_in.has_capacity == get(e_true, :has_capacity, false)
    @test e_in.can_retire == get(e_true, :can_retire, false)
    @test e_in.can_expand == get(e_true, :can_expand, false)
    @test e_in.capacity_size == get(e_true, :capacity_size, 1.0)
    @test e_in.availability == get(e_true, :availability, Float64[])
    @test e_in.min_capacity == get(e_true, :min_capacity, 0.0)
    e_true_max_capacity =
        get(e_true, :max_capacity, "Inf") == "Inf" ? Inf : get(e_true, :max_capacity, Inf)
    @test e_in.max_capacity == e_true_max_capacity
    @test e_in.existing_capacity == get(e_true, :existing_capacity, 0.0)
    @test e_in.investment_cost == get(e_true, :investment_cost, 0.0)
    @test e_in.fixed_om_cost == get(e_true, :fixed_om_cost, 0.0)
    @test e_in.variable_om_cost == get(e_true, :variable_om_cost, 0.0)
    @test e_in.ramp_up_fraction == get(e_true, :ramp_up_fraction, 1.0)
    @test e_in.ramp_down_fraction == get(e_true, :ramp_down_fraction, 1.0)
    @test e_in.min_flow_fraction == get(e_true, :min_flow_fraction, 0.0)
    @test e_in.distance == get(e_true, :distance, 0.0)
    @test e_in.capacity == get(e_true, :capacity, 0.0)
    @test e_in.new_capacity == get(e_true, :new_capacity, 0.0)
    @test e_in.retired_capacity == get(e_true, :retired_capacity, 0.0)
    @test e_in.flow == get(e_true, :flow, Vector{VariableRef}())
    test_load(e_in.constraints, get(e_true, :constraints, Vector{AbstractTypeConstraint}()))
    return nothing
end

function test_load(e_in::EdgeWithUC{T}, e_true::S) where {T<:Commodity,S<:JSON3.Object}
    invoke(test_load, Tuple{AbstractEdge{T},S}, e_in, e_true)
    @test e_in.min_up_time == get(e_true, :min_up_time, 0)
    @test e_in.min_down_time == get(e_true, :min_down_time, 0)
    @test e_in.startup_cost == get(e_true, :startup_cost, 0.0)
    @test e_in.startup_fuel_consumption == get(e_true, :startup_fuel_consumption, 0.0)
    @test e_in.startup_fuel_balance_id ==
          Symbol(get(e_true, :startup_fuel_balance_id, "node"))
    @test e_in.ucommit == get(e_true, :ucommit, Vector{VariableRef}())
    @test e_in.ustart == get(e_true, :ustart, Vector{VariableRef}())
    @test e_in.ushut == get(e_true, :ushut, Vector{VariableRef}())
    return nothing
end

function test_load(n_in::Node{T}, n_true::S) where {T<:Commodity,S<:JSON3.Object}
    @test Symbol(T) == Symbol(n_true.type)
    n_true_instance_data = n_true.instance_data
    @test n_in.id == Symbol(n_true_instance_data.id)
    @test typesymbol(commodity_type(n_in.timedata)) == Symbol(n_true_instance_data.timedata)
    @test n_in.demand == get(n_true_instance_data, :demand, Vector{Float64}())
    @test n_in.price == get(n_true_instance_data, :price, Float64[])
    @test n_in.max_nsd == get(n_true_instance_data, :max_nsd, [0.0])
    @test n_in.price_nsd == get(n_true_instance_data, :price_nsd, [0.0])
    @test n_in.price_unmet_policy ==
          get(n_true_instance_data, :price_unmet_policy, Dict{DataType,Float64}())
    test_load(
        n_in.price_unmet_policy,
        get(n_true_instance_data, :price_unmet_policy, Dict{DataType,Float64}()),
    )
    test_load(
        n_in.rhs_policy,
        get(n_true_instance_data, :rhs_policy, Dict{DataType,Float64}()),
    )
    test_load(
        n_in.constraints,
        get(n_true_instance_data, :constraints, Vector{AbstractTypeConstraint}()),
    )
    return nothing
end

function test_load(t_in::Transformation, t_true::T) where {T<:JSON3.Object}
    @test t_in.id == Symbol(t_true.id)
    @test typesymbol(commodity_type(t_in.timedata)) == Symbol(t_true.timedata)
    test_load(t_in.constraints, get(t_true, :constraints, Vector{AbstractTypeConstraint}()))
    return nothing
end

function test_load(s_in::AbstractStorage{T}, s_true::S) where {T<:Commodity,S<:JSON3.Object}
    @test s_in.id == Symbol(s_true.id)
    @test Symbol(commodity_type(s_in.timedata)) == Symbol(s_true.timedata)
    @test s_in.capacity == get(s_true, :capacity, 0.0)
    @test s_in.new_capacity == get(s_true, :new_capacity, 0.0)
    @test s_in.retired_capacity == get(s_true, :retired_capacity, 0.0)
    @test s_in.storage_level == get(s_true, :storage_level, Vector{VariableRef}())
    @test s_in.min_capacity == get(s_true, :min_capacity, 0.0)
    s_true_max_capacity =
        get(s_true, :max_capacity, "Inf") == "Inf" ? Inf :
        get(s_true, :max_capacity, Inf)
    @test s_in.max_capacity == s_true_max_capacity
    @test s_in.existing_capacity == get(s_true, :existing_capacity, 0.0)
    @test s_in.can_expand == get(s_true, :can_expand, false)
    @test s_in.can_retire == get(s_true, :can_retire, false)
    @test s_in.investment_cost == get(s_true, :investment_cost, 0.0)
    @test s_in.fixed_om_cost == get(s_true, :fixed_om_cost, 0.0)
    @test s_in.min_storage_level == get(s_true, :min_storage_level, 0.0)
    @test s_in.min_duration == get(s_true, :min_duration, 0.0)
    @test s_in.max_duration == get(s_true, :max_duration, 0.0)
    @test s_in.loss_fraction == Float64[]
    test_load(s_in.constraints, get(s_true, :constraints, Vector{AbstractTypeConstraint}()))
    return nothing
end

function test_load(a_in::AbstractAsset, a_true::T) where {T<:JSON3.Object}
    # @test Symbol(typeof(a_in)) == Symbol(a_true.type)
    a_true_instance_data = a_true.instance_data
    for t in Base.fieldnames(typeof(a_in))
        data_in = getfield(a_in, t)
        if isa(data_in, AssetId)
            test_load(data_in, a_true_instance_data.id)
        elseif isa(data_in, Edge) || isa(data_in, EdgeWithUC)
            test_load(data_in, a_true_instance_data.edges[t])
        elseif isa(data_in, Storage)
            test_load(data_in, a_true_instance_data.storage)
        elseif isa(data_in, Transformation)
            test_load(data_in, a_true_instance_data.transforms)
        end
    end
    return nothing
end

function test_load(s_in::System, s_true::T) where {T<:JSON3.Object}
    test_configure_settings(s_in.settings, s_true.settings)
    test_load_commodities(s_in.commodities, s_true.commodities)
    test_load(s_in.locations, s_true.nodes)
    test_load(s_in.assets, s_true.assets)
    return nothing
end

function test_load_inputs()
    system = load_system(test_path)
    system_true = read_file(joinpath(test_path, system_data_true_path))
    test_load(system, system_true)
    return system
end

function test_model_generation_and_optimization()
    case = load_case(test_path)
    optimizer = create_optimizer(optim)
    model = generate_model(case,optimizer)
    optimize!(model)
    macro_objval = objective_value(model)

    @test macro_objval ≈ obj_true

    test_writing_outputs(case, model)

    return nothing
end

function test_writing_outputs(case,model)
    system = case.systems[1];
    settings = case.settings;
    @test_nowarn get_optimal_capacity(system)
    @test_nowarn get_optimal_new_capacity(system)
    @test_nowarn get_optimal_retired_capacity(system)
    @test_nowarn get_optimal_capacity(system.assets[1], scaling=1.0)
    @test_nowarn get_optimal_new_capacity(system.assets[1])
    @test_nowarn get_optimal_retired_capacity(system.assets[1])
    @test_nowarn get_optimal_flow(system)
    @test_nowarn get_optimal_flow(system.assets[1], scaling=1.0)
    @test_nowarn get_optimal_flow(system.assets[1].elec_edge, 1.0)
    @test_nowarn create_discounted_cost_expressions!(model,system,settings)
    @test_nowarn compute_undiscounted_costs!(model, system, settings)
    @test_nowarn get_optimal_discounted_costs(model)
    @test_nowarn get_optimal_discounted_costs(model,scaling=2.0)
    @test_nowarn get_optimal_undiscounted_costs(model)
    @test_nowarn get_optimal_undiscounted_costs(model, scaling=2.0)
    @test_nowarn write_capacity("test_capacity.csv", system)
    @test_nowarn write_costs("test_costs.csv", system, model)
    @test_nowarn write_undiscounted_costs("test_undiscountedcosts.csv", system, model)
    @test_nowarn write_flow("test_flow.csv", system)
    @test_nowarn write_curtailment("test_curtailment.csv", system)
    # Detailed cost breakdown (monolithic)
    @test_nowarn write_detailed_costs(".", system, model, settings)
    costs_result = get_detailed_costs(system, settings)
    detailed_costs = costs_result.undiscounted
    @test detailed_costs isa DataFrame
    @test !isempty(detailed_costs)
    @test all(c in names(detailed_costs) for c in ["zone", "type", "category", "value"])
    # Return structure: both discounted and undiscounted have same columns and row count
    @test names(costs_result.discounted) == ["zone", "type", "category", "value"]
    @test names(costs_result.undiscounted) == ["zone", "type", "category", "value"]
    @test size(costs_result.discounted, 1) == size(costs_result.undiscounted, 1)
    # Grand total from detailed costs should match model total (same values written to test_costs.csv)
    @test sum(costs_result.discounted.value) ≈ value(model[:eDiscountedFixedCost]) + value(model[:eDiscountedVariableCost])
    @test sum(costs_result.undiscounted.value) ≈ value(model[:eFixedCost]) + value(model[:eVariableCost])
    @test isfile("costs_by_type.csv")
    @test isfile("costs_by_zone.csv")
    @test isfile("undiscounted_costs_by_type.csv")
    @test isfile("undiscounted_costs_by_zone.csv")
    rm("costs_by_type.csv") # clean up
    rm("costs_by_zone.csv") # clean up
    rm("undiscounted_costs_by_type.csv") # clean up
    rm("undiscounted_costs_by_zone.csv") # clean up
    rm("test_capacity.csv")     # clean up
    rm("test_costs.csv")        # clean up
    rm("test_undiscountedcosts.csv")        # clean up
    rm("test_flow.csv")         # clean up
    isfile("test_curtailment.csv") && rm("test_curtailment.csv")  # clean up
    return nothing
end 

function test_workflow()
    @testset "Struct Creation Tests" begin
        test_load_inputs()
    end
    @testset "Model Generation and Optim Tests   " begin
        @warn_error_logger test_model_generation_and_optimization()
    end

    return nothing
end

test_workflow()

end # module TestWorkflow
