module TestWorkflow

using Test
using Gurobi, HiGHS
using CSV, DataFrames, JSON3
import Macro:
    System,
    AbstractEdge,
    Edge,
    EdgeWithUC,
    Node,
    Transformation,
    Storage,
    TimeData,
    Commodity,
    AbstractAsset,
    AbstractTypeConstraint,
    load_system,
    generate_model,
    set_optimizer,
    optimize!,
    objective_value,
    commodity_type,
    AssetId,
    VariableRef


include("utilities.jl")

const test_path = joinpath(@__DIR__, "test_inputs")
const optim = is_gurobi_available() ? Gurobi.Optimizer : HiGHS.Optimizer


function test_configure_settings(data::NamedTuple, data_true::T) where {T<:JSON3.Object}
    @test data.UCommit == data_true.UCommit
    @test data.NetworkExpansion == data_true.NetworkExpansion
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
        @test name in propertynames(data_true)
        @test data_true[name]   # check that the constraint is set to true in the JSON file
    end
    return nothing
end

function test_load(e_in::AbstractEdge{T}, e_true::S) where {T<:Commodity,S<:JSON3.Object}
    @test e_in.start_vertex.id == Symbol(e_true.start_vertex)
    @test e_in.end_vertex.id == Symbol(e_true.end_vertex)
    @test Symbol(commodity_type(e_in.timedata)) == Symbol(e_true.timedata)
    @test e_in.unidirectional == get(e_true, :unidirectional, true)
    @test e_in.has_planning_variables == get(e_true, :has_planning_variables, false)
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
    @test e_in.price == get(e_true, :price, Float64[])
    @test e_in.ramp_up_fraction == get(e_true, :ramp_up_fraction, 1.0)
    @test e_in.ramp_down_fraction == get(e_true, :ramp_down_fraction, 1.0)
    @test e_in.min_flow_fraction == get(e_true, :min_flow_fraction, 0.0)
    @test e_in.distance == get(e_true, :distance, 0.0)
    @test e_in.capacity == get(e_true, :capacity, 0.0)
    @test e_in.new_capacity == get(e_true, :new_capacity, 0.0)
    @test e_in.ret_capacity == get(e_true, :ret_capacity, 0.0)
    @test e_in.flow == get(e_true, :flow, Vector{VariableRef}())
    test_load(e_in.constraints, get(e_true, :constraints, Vector{AbstractTypeConstraint}()))
    return nothing
end

function test_load(e_in::EdgeWithUC{T}, e_true::S) where {T<:Commodity,S<:JSON3.Object}
    invoke(test_load, Tuple{AbstractEdge{T},S}, e_in, e_true)
    @test e_in.min_up_time == get(e_true, :min_up_time, 0)
    @test e_in.min_down_time == get(e_true, :min_down_time, 0)
    @test e_in.startup_cost == get(e_true, :startup_cost, 0.0)
    @test e_in.startup_fuel == get(e_true, :startup_fuel, 0.0)
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
    @test Symbol(commodity_type(n_in.timedata)) == Symbol(n_true_instance_data.timedata)
    @test n_in.demand == get(n_true_instance_data, :demand, Vector{Float64}())
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
    @test Symbol(commodity_type(t_in.timedata)) == Symbol(t_true.timedata)
    test_load(t_in.constraints, get(t_true, :constraints, Vector{AbstractTypeConstraint}()))
    return nothing
end

function test_load(s_in::Storage{T}, s_true::S) where {T<:Commodity,S<:JSON3.Object}
    @test s_in.id == Symbol(s_true.id)
    @test Symbol(commodity_type(s_in.timedata)) == Symbol(s_true.timedata)
    @test s_in.capacity_storage == get(s_true, :capacity_storage, 0.0)
    @test s_in.new_capacity_storage == get(s_true, :new_capacity_storage, 0.0)
    @test s_in.ret_capacity_storage == get(s_true, :ret_capacity_storage, 0.0)
    @test s_in.storage_level == get(s_true, :storage_level, Vector{VariableRef}())
    @test s_in.min_capacity_storage == get(s_true, :min_capacity_storage, 0.0)
    s_true_max_capacity =
        get(s_true, :max_capacity_storage, "Inf") == "Inf" ? Inf :
        get(s_true, :max_capacity_storage, Inf)
    @test s_in.max_capacity_storage == s_true_max_capacity
    @test s_in.existing_capacity_storage == get(s_true, :existing_capacity_storage, 0.0)
    @test s_in.can_expand == get(s_true, :can_expand, false)
    @test s_in.can_retire == get(s_true, :can_retire, false)
    @test s_in.investment_cost_storage == get(s_true, :investment_cost_storage, 0.0)
    @test s_in.fixed_om_cost_storage == get(s_true, :fixed_om_cost_storage, 0.0)
    @test s_in.min_storage_level == get(s_true, :min_storage_level, 0.0)
    @test s_in.min_duration == get(s_true, :min_duration, 0.0)
    @test s_in.max_duration == get(s_true, :max_duration, 0.0)
    @test s_in.storage_loss_fraction == get(s_true, :storage_loss_fraction, 0.0)
    test_load(s_in.constraints, get(s_true, :constraints, Vector{AbstractTypeConstraint}()))
    return nothing
end

function test_load(a_in::AbstractAsset, a_true::T) where {T<:JSON3.Object}
    @test Symbol(typeof(a_in)) == Symbol(a_true.type)
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
    #TODO: add test to time data
    test_load(s_in.locations, s_true.nodes)
    test_load(s_in.assets, s_true.assets)
    return nothing
end

function test_load_inputs()
    system = load_system(test_path)
    system_true = JSON3.read(joinpath(test_path, "system_data_true.json"))
    test_load(system, system_true)
    return system
end

function test_model_generation_and_optimization()
    system = load_system(test_path)
    model = generate_model(system)
    set_optimizer(model, optim)
    optimize!(model)
    macro_objval = objective_value(model)

    @test macro_objval == 2.1059615254166523e10

    return nothing
end

function test_workflow()
    @testset "Test Struct Creation" begin
        test_load_inputs()
    end
    @testset "Test Model Generation and Optimization" begin
        @warn_error_logger test_model_generation_and_optimization()
    end
    return nothing
end

test_workflow()

end # module TestWorkflow
