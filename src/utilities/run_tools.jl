function run_case(
    case_path::AbstractString=@__DIR__; 
    lazy_load::Bool=true, 
    optimizer::DataType=HiGHS.Optimizer, 
    optimizer_env::Any=missing,
    attributes::AbstractDict{Symbol,<:Any}=Dict(:BarConvTol=>1e-3, :Crossover => 0, :Method => 2)
)

    println("###### ###### ######")
    println("Running case at $(case_path)")

    stages = load_stages(case_path; lazy_load=lazy_load)

    optimizer = create_optimizer(optimizer, optimizer_env, attributes)

    (stages, model) = solve_stages(stages, optimizer)
    
    write_outputs(case_path, stages, model)

    return stages.systems, model
end

function run_multistage_case(case_path::AbstractString=@__DIR__; num_stages::Int64=1, perfect_foresight::Bool = false, lazy_load::Bool=true, optimizer::DataType=HiGHS.Optimizer, optimizer_env::Any=missing)
    
    println("###### ###### ######")
    println("Running multistage case at $(case_path)")

    case_path_vec = [case_path*"/stage$i/" for i in 1:num_stages]

    @show case_path_vec

    system_vec = load_system.(case_path_vec; lazy_load=lazy_load)

    if perfect_foresight

        @info("*** Running with perfect foresight ***")

        @info("Discounting all fixed costs")

        discount_fixed_costs!.(system_vec)
    
        @info("Computing retirement stages for age based retirements")

        compute_retirement_stage!.(system_vec)
        
        model = generate_multistage_model_foresight(system_vec);

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
            set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)
        catch
            @warn("Error setting optimizer attributes. Check that the optimizer is valid.")
        end

        if system_vec[1].settings.ConstraintScaling
            @info "Scaling constraints and RHS"
            scale_constraints!(model)
        end

        optimize!(model)

        for i in 1:num_stages
            # Output results
            results_dir = joinpath(case_path, "results_stage$i")
            mkpath(results_dir)
            
            # Capacity results
            write_capacity_results(joinpath(results_dir, "capacity.csv"), system_vec[i])
            
            # Cost results
            # write_costs(joinpath(results_dir, "costs.csv"), model)
        end
    
        return system_vec, model

    else
        @info("*** Running myopic simulation ***")

        @info("Note that we do not apply any discount when running a myopic case")

        @info("Computing retirement stages for age based retirements")

        compute_retirement_stage!.(system_vec)

        model_vec = Vector{MacroEnergy.AbstractModel}(undef,3)

        for i in 1:num_stages

            @info("Starting stage $i....")

            model = generate_model(system_vec[i])

            @info(" -- Including age-based retirements")
            add_age_based_retirements!.(system_vec[i].assets, model)

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
                set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)
            catch
                @warn("Error setting optimizer attributes. Check that the optimizer is valid.")
            end
    
            if system_vec[1].settings.ConstraintScaling
                @info "Scaling constraints and RHS"
                scale_constraints!(model)
            end

            optimize!(model)

            if !has_values(model)
                compute_conflict!(model)
                list_of_conflicting_constraints = ConstraintRef[];
                for (F, S) in list_of_constraint_types(model)
                    for con in JuMP.all_constraints(model, F, S)
                        if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                            push!(list_of_conflicting_constraints, con)
                        end
                    end
                end
                display(list_of_conflicting_constraints)
            end

            if i < num_stages
                @info(" -- Final capacity in stage $(i) is being carried over to stage $(i+1)")
                initialize_stage_capacities!(system_vec[i+1],system_vec[i],perfect_foresight=false)
            end

            model_vec[i] = model;

            # Output results
            results_dir = joinpath(case_path, "results_stage$i")
            mkpath(results_dir)
            
            # Capacity results
            write_capacity_results(joinpath(results_dir, "capacity.csv"), system_vec[i])
            
            # Cost results
            write_costs(joinpath(results_dir, "costs.csv"), model)

        end
    
        return system_vec, model_vec
    end

end

