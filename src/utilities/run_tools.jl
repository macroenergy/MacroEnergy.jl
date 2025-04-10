function run_case(case_path::AbstractString=@__DIR__; lazy_load::Bool=true, optimizer::DataType=HiGHS.Optimizer, optimizer_env::Any=missing)
    println("###### ###### ######")
    println("Running case at $(case_path)")

    system = load_system(case_path; lazy_load=lazy_load)

    model = generate_model(system)

    if !ismissing(optimizer_env)
        try 
            set_optimizer(model, () -> optimizer(optimizer_env));
        catch
            error("Error creating optimizer with environment. Check that the environment is valid.")
        end
    else
        set_optimizer(model, optimizer);
    end

    try
        set_optimizer_attributes(model, "BarConvTol"=>1e-8,"Crossover" => 1, "Method" => 2)
    catch
        @warn("Error setting optimizer attributes. Check that the optimizer is valid.")
    end

    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    optimize!(model)
    
    ## Output results
    # Create results directory
    results_dir = create_output_path(system)
    
    # Capacity results
    write_capacity(joinpath(results_dir, "capacity.csv"), system)
    
    # Cost results
    write_costs(joinpath(results_dir, "costs.csv"), system, model)

    # Flow results
    write_flow(joinpath(results_dir, "flow.csv"), system)

    return system, model
end