module TestDuals

using Test
using HiGHS
using Statistics
using CSV, DataFrames, JSON3
using JuMP
import MacroEnergy:
    BalanceConstraint,
    Case,
    CO2,
    CO2CapConstraint,
    Electricity,
    Node,
    TimeData,
    System,
    balance_ids,
    constraint_dual,
    current_subperiod,
    ensure_duals_available!,
    generate_model,
    get_constraint_by_type,
    get_transformations,
    has_duals,
    id,
    load_case,
    objective_value,
    optimize!,
    set_constraint_dual!,
    set_logger,
    set_optimizer,
    subperiod_weight,
    time_interval,
    write_balance_duals,
    write_co2_cap_duals,
    write_duals

include("utilities.jl")

const test_path = joinpath(@__DIR__, "test_small_case")
const optim = HiGHS.Optimizer

# Global variables for true results
const balance_duals_describe_true = DataFrame(
    variable = [:elec_MA, :elec_CT, :elec_ME],
    mean = [76.74351137701892, 52.287, 47.5399],
    min = [0.1, 0.1, 0.1],
    median = [0.44536862003780714, 0.1, 0.1],
    max = [322.0473244450625, 288.732, 322.047],
    nmissing = [0, 0, 0],
    eltype = [Float64, Float64, Float64]
)
const balance_duals_sum_true = DataFrame(
    variable = [:elec_MA, :elec_CT, :elec_ME],
    sum = [5525.532819145362, 3764.6638182861698, 3422.871922377889]
)

# Set logger to Error level
set_logger(true, true, Logging.Error, joinpath(test_path, "test_duals.log"))

# Helper function to describe the duals for a given node 
# and compare them to the true results from input files
function custom_describe(id::Symbol, duals::Vector{Float64})
    return DataFrame(
        variable = id,
        mean = mean(duals),
        min = minimum(duals),
        median = median(duals),
        max = maximum(duals),
        nmissing = sum(ismissing.(duals)),
        eltype = eltype(duals)
    )
end 

function test_ensure_duals_available!()
    @testset "ensure_duals_available! Tests" begin
        # Load case and generate model
        case = load_case(test_path)
        model = generate_model(case)
        set_optimizer(model, optim)
        set_silent(model)
        optimize!(model)

        # Test that model is solved to optimality
        @test termination_status(model) == MOI.OPTIMAL
        
        # HiGHS provides duals for LP problems
        @test_nowarn ensure_duals_available!(model)
        @test has_duals(model)

        # Return and cache case and model
        return case, model
    end
end

# Test that the duals are set correctly for a given node
function test_set_constraint_dual!(case, model)
    @testset "set_constraint_dual! Tests" begin
        
        # Assert that model is solved to optimality
        @assert termination_status(model) == MOI.OPTIMAL

        system = case.systems[1]
        
        # Find a node with a balance constraint
        test_node = nothing
        for location in system.locations
            if location isa Node{Electricity}
                test_node = location
                break
            end
        end
        
        @test !isnothing(test_node)
        
        # Get the balance constraint
        balance_constraint = get_constraint_by_type(test_node, BalanceConstraint)
        @test !isnothing(balance_constraint)
        
        # Initially, constraint_dual should be missing
        @test ismissing(constraint_dual(balance_constraint))
        
        # Extract dual values using set_constraint_dual!
        @test_nowarn set_constraint_dual!(balance_constraint, test_node)
        
        # After extraction, constraint_dual should be a Dict
        duals_dict = constraint_dual(balance_constraint)
        @test duals_dict isa Dict{Symbol, Vector{Float64}}
        @test !isempty(duals_dict)
        
        # Check that all balance IDs are present
        node_balance_ids = balance_ids(test_node)
        for balance_id in node_balance_ids
            @test haskey(duals_dict, balance_id)
            @test duals_dict[balance_id] isa Vector{Float64}
            @test length(duals_dict[balance_id]) > 0
        end
        
        # Check that demand key is present
        if :demand in node_balance_ids
            demand_duals = duals_dict[:demand]
            @test length(demand_duals) == length(test_node.timedata.time_interval)
            @test all(isfinite, demand_duals)
        end
    end
end

# Test that the balance duals are written correctly to a CSV file
function test_write_balance_duals(case, model)
    @testset "write_balance_duals Tests" begin

        # Assert that model is solved to optimality
        @assert termination_status(model) == MOI.OPTIMAL

        system = case.systems[1]
        
        # Create temporary directory for outputs
        temp_dir = abspath(mktempdir("."))
        
        try
            @test_logs (:info, "Writing balance constraint dual values to $(temp_dir)") write_balance_duals(temp_dir, system)

            # Check that balance_duals.csv was created
            output_file = joinpath(temp_dir, "balance_duals.csv")
            @test isfile(output_file)
            
            # Read and validate the CSV file
            df = CSV.read(output_file, DataFrame)

            @test nrow(df) > 0
            @test ncol(df) > 0
            
            node_ids = names(df)
            @test length(node_ids) > 0
            
            for col in names(df)
                @test eltype(df[!, col]) <: Real
                @test all(isfinite, df[!, col])
            end
            
            test_node = findfirst(n -> n isa Node{Electricity}, system.locations)
            if !isnothing(test_node)
                node = system.locations[test_node]
                @test nrow(df) == length(node.timedata.time_interval)
            end

            # Verify that the duals are consistent with the "true results"
            balance_duals_true = CSV.read(joinpath(test_path, "results", "balance_duals_true.csv"), DataFrame)
            @test isapprox(df, balance_duals_true, atol=1e-10)
            
        finally
            # Cleanup
            rm(temp_dir, recursive=true)
        end
    end
end

# Test that the CO2 cap duals are written correctly to a CSV file
function test_write_co2_cap_duals(case, model)
    @testset "write_co2_cap_duals Tests" begin

        # Assert that model is solved to optimality
        @assert termination_status(model) == MOI.OPTIMAL

        system = case.systems[1]
        
        # Create temporary directory for outputs
        temp_dir = abspath(mktempdir("."))
        
        try
            # Write CO2 cap duals
            @test_logs (:info, "Writing CO2 cap constraint dual values to $(temp_dir)") write_co2_cap_duals(temp_dir, system)
            
            # Check if co2_cap_duals.csv was created
            output_file = joinpath(temp_dir, "co2_cap_duals.csv")
            
            if isfile(output_file)
                # If file exists, validate its structure
                df = CSV.read(output_file, DataFrame)
                
                # Test duals are consistent with the "true results"
                co2_cap_duals_true = CSV.read(joinpath(test_path, "results", "co2_cap_duals_true.csv"), DataFrame)
                @test df.Node == co2_cap_duals_true.Node
                @test isapprox(df[:, Not(:Node)], co2_cap_duals_true[:, Not(:Node)], atol=1e-10)

                @test "Node" in names(df)
                @test "CO2_Shadow_Price" in names(df)
                
                @test df.Node isa Vector{Symbol} || df.Node isa Vector{String} || df.Node isa Vector{String15}
                @test eltype(df.CO2_Shadow_Price) <: Real
                
                if "CO2_Slack" in names(df)
                    @test eltype(df.CO2_Slack) <: Real
                end
                
                @test all(isfinite, df.CO2_Shadow_Price)
            else
                @error "No CO2 cap constraints found in test case, skipping CO2 duals validation"
            end
            
        finally
            # Cleanup
            rm(temp_dir, recursive=true)
        end
    end
end

# Test that the duals are written correctly to a CSV file
function test_write_duals(case, model)
    @testset "write_duals Tests" begin

        # Assert that model is solved to optimality
        @assert termination_status(model) == MOI.OPTIMAL

        system = case.systems[1]
        
        # Create temporary directory for outputs
        temp_dir = abspath(mktempdir("."))
        
        try
            # Write all duals to CSV files
            @test_logs (:info, "Writing constraint dual values to $(temp_dir)") (:info, "Writing balance constraint dual values to $(temp_dir)") (:info, "Writing CO2 cap constraint dual values to $(temp_dir)") write_duals(temp_dir, system)
            
            # Check that balance_duals.csv was created
            balance_file = joinpath(temp_dir, "balance_duals.csv")
            @test isfile(balance_file)
            
            df_balance = CSV.read(balance_file, DataFrame)
            @test nrow(df_balance) > 0
            @test ncol(df_balance) > 0
            
            # Check for co2_cap_duals.csv
            co2_file = joinpath(temp_dir, "co2_cap_duals.csv")
            df_co2 = CSV.read(co2_file, DataFrame)
            @test nrow(df_co2) > 0
            @test "Node" in names(df_co2)
            @test "CO2_Shadow_Price" in names(df_co2)
        finally
            # Cleanup
            rm(temp_dir, recursive=true)
        end
    end
end

# Test that the dual values are consistent with the "true results"
function test_dual_values_consistency(case, model)
    @testset "Dual Values Consistency Tests" begin

        # Assert that model is solved to optimality
        @assert termination_status(model) == MOI.OPTIMAL

        system = case.systems[1]
        
        # Find a node with a demand balance equation
        test_node = nothing
        for location in system.locations
            if location isa Node{Electricity} && !isempty(location.demand) && sum(location.demand) > 0
                test_node = location
                break
            end
        end
        
        if !isnothing(test_node)
            # Get balance constraint
            balance_constraint = get_constraint_by_type(test_node, BalanceConstraint)
            node_id = id(test_node)
            
            if !isnothing(balance_constraint)
                # Extract duals for the demand balance equation
                set_constraint_dual!(balance_constraint, test_node)
                duals_dict = constraint_dual(balance_constraint)
                
                # Get the duals for the demand balance equation
                demand_duals = duals_dict[:demand]
                weights = Float64[subperiod_weight(test_node, current_subperiod(test_node, t)) for t in time_interval(test_node)]
                demand_duals_rescaled = demand_duals ./ weights

                @test all(isfinite, demand_duals)
                @test length(demand_duals_rescaled) == length(test_node.timedata.time_interval)
                
                # Test that duals are consistent with the true results
                balance_duals_describe_true_node = balance_duals_describe_true[balance_duals_describe_true.variable .== node_id, :]
                for num_col in [:mean, :min, :median, :max, :nmissing]
                    @test isapprox(custom_describe(node_id, demand_duals_rescaled)[!, num_col], balance_duals_describe_true_node[!, num_col], atol=1e-10)
                end
                for symbol_col in [:variable, :eltype]
                    @test custom_describe(node_id, demand_duals_rescaled)[!, symbol_col] == balance_duals_describe_true_node[!, symbol_col]
                end
                balance_duals_sum_true_node = balance_duals_sum_true[balance_duals_sum_true.variable .== node_id, :]
                @test isapprox(sum(demand_duals_rescaled), balance_duals_sum_true_node.sum[1], atol=1e-10)
            end
        else
            @error "No node with a demand balance equation found, skipping consistency tests"
        end
    end
end

# Test that the duals are set correctly for multiple balance equations
function test_multiple_balance_ids(case, model)
    @testset "Multiple Balance IDs Tests" begin
        @assert termination_status(model) == MOI.OPTIMAL

        system = case.systems[1]
        
        # Find vertices with balance equations and check their balance IDs
        transforms = get_transformations(system)
        nodes = [n for n in system.locations if n isa Node]
        for vertex in vcat(nodes, transforms)
            balance_constraint = get_constraint_by_type(vertex, BalanceConstraint)
            
            if !isnothing(balance_constraint) && !ismissing(balance_constraint.constraint_ref)
                # Get balance IDs for this vertex
                node_balance_ids = balance_ids(vertex)
                
                # Extract duals
                set_constraint_dual!(balance_constraint, vertex)
                duals_dict = constraint_dual(balance_constraint)
                
                # Verify that all balance IDs have corresponding duals
                @test Set(keys(duals_dict)) == Set(node_balance_ids)
                
                # Verify structure for each balance ID
                for balance_id in node_balance_ids
                    @test haskey(duals_dict, balance_id)
                    @test duals_dict[balance_id] isa Vector{Float64}
                    @test length(duals_dict[balance_id]) == length(vertex.timedata.time_interval)
                end
            end
        end
    end
end

# Test that the error handling of set_constraint_dual! works correctly
function test_error_handling()
    @testset "Error Handling Tests" begin
        # Test with node that has no constraint reference
        test_node = Node{Electricity}(
            id=:test_node,
            timedata=TimeData{Electricity}(
                time_interval=1:3,
                hours_per_timestep=1,
                subperiods=[1:3],
                subperiod_indices=[1],
                subperiod_weights=Dict(1 => 1.0)
            )
        )
        
        # Test that the node has no constraints
        @test isempty(test_node.constraints)

        # Create a balance constraint without constraint_ref
        balance_constraint = BalanceConstraint()
        
        # Should error when trying to extract duals
        @test_throws ErrorException set_constraint_dual!(balance_constraint, test_node)
    end
end

"""
    run_all_dual_tests()

Run all dual value export tests.
"""
function run_all_dual_tests()
    case, model = test_ensure_duals_available!()
    test_set_constraint_dual!(case, model)
    test_multiple_balance_ids(case, model)
    test_dual_values_consistency(case, model)
    test_write_balance_duals(case, model)
    test_write_co2_cap_duals(case, model)
    test_write_duals(case, model)
    test_error_handling()
end

run_all_dual_tests()

end # module TestDuals

