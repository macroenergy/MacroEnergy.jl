using Macro

case_dir = joinpath(@__DIR__, "eastern_us_three_zones")
case_system_data = joinpath(case_dir, "system_data.json")

result_indicator = Any[]

macro test_case(test_expression, result_indicator)
    # Wrap the test_expression in a try-catch block to catch any errors
    # If the test_expression throws an error, the error message is stored in the result_indicator, starting with a red circle
    # If the test_expression runs without error, the result_indicator is a green circle
    return :(
        try
            $test_expression
            push!($result_indicator, "🟢")
        catch e
            push!($result_indicator, "🔴")
            push!(result_indicator, e)
        end
    )
end

# Test loading system directly, with and without lazy loading

@test_case system_from_dir_lazy = Macro.load_system(case_dir) result_indicator
@test_case system_from_file_lazy = Macro.load_system(case_system_data) result_indicator

@test_case system_from_dir_eager = Macro.load_system(case_dir, lazy_load=false) result_indicator
@test_case system_from_file_eager = Macro.load_system(case_system_data, lazy_load=false) result_indicator

######

# Test loading system data, with lazy loading and implicit case directory (= dirname(case_system_data))
@test_case system_data_from_file_implicit_dir_lazy = Macro.load_system_data(case_system_data) result_indicator

# Test loading system data, with lazy loading and explicit case directory
@test_case system_data_from_file_explicit_dir_lazy = Macro.load_system_data(case_system_data, case_dir) result_indicator

# Test loading system data, with eager loading and implicit case directory (= dirname(case_system_data))
@test_case system_data_from_file_implicit_dir_eager = Macro.load_system_data(case_system_data; lazy_load=false) result_indicator

# Test loading system data, with eager loading and explicit case directory
@test_case system_data_from_file_explicit_dir_eager = Macro.load_system_data(case_system_data, case_dir; lazy_load=false) result_indicator

for x in result_indicator
    println(x)
end

######

function walk_through(case_dir)
    lazy_load = false
    # Walking through system_from_dir_eager = Macro.load_system(case_dir, lazy_load=false)
    path = case_dir # --> .../Macro/ExampleSystems/three_zones_macro_genx
    println(path) # --> .../Macro/ExampleSystems/three_zones_macro_genx
    if Macro.isjson(path)
        path = Macro.rel_or_abs_path(path)
    else
        # Assume it's a dir, ignoring other possible suffixes
        path = Macro.rel_or_abs_path(joinpath(path, "system_data.json"))
    end
    println(path) # --> .../Macro/ExampleSystems/three_zones_macro_genx/system_data.json

    println(isfile(path)) # --> true

    # We're proceeding assuming the file exists
    system = Macro.empty_system(dirname(path))
    println(system)

    ### system_data = Macro.load_system_data(path; lazy_load=lazy_load)
        # This calls Macro.load_system_data(path, dirname(path); default_file_path=default_file_path, lazy_load=lazy_load)
        rel_path = dirname(path) 
        println(rel_path) # --> .../Macro/ExampleSystems/three_zones_macro_genx

        # This then checks whether to use the relative or absolute file_path
        file_path = abspath(Macro.rel_or_abs_path(path, rel_path))
        println(file_path) # --> .../Macro/ExampleSystems/three_zones_macro_genx/system_data.json

        default_file_path = joinpath(@__DIR__, "..", "src", "load_inputs", "default_system_data.json")

        Macro.prep_system_data(file_path, default_file_path)

    # Macro.generate_system!(system, system_data)
    return system

end

walk_through(case_dir);