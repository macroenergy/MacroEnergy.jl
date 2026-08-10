# Suggested Development Workflow

When developing a new model, and in general when working with Macro and Julia, we recommend that you run your models and Julia commands in a Julia REPL:

```julia
julia> using MacroEnergy, HiGHS
julia> # Load a system
julia> system = load_system("path/to/system_data.json")
julia> # Create the optimizer
julia> optimizer = create_optimizer(HiGHS.Optimizer)
julia> # Generate a model
julia> model = generate_model(system,optimizer)
julia> # Run optimization
julia> optimize!(model)
# [... other commands ...]
```

This interactive approach is recommended instead of creating a script and running it directly from the terminal:

```bash
julia my_new_model.jl
```

## Using VS Code

If using VS Code, this workflow is particularly easy to implement with the Julia extension enabled. You can:
1. Open your script
2. Move the cursor to any line
3. Press `cmd/ctrl + return/enter` to execute that line in an **interactive REPL**
4. Select multiple lines and use the same shortcut to execute them as a group

## Benefits of the Interactive Workflow

- **Performance**: Julia's JIT (Just-In-Time) compilation means each method is compiled the first time it's called. Subsequent calls with the same argument types will be much faster, as the compiled code is cached.

- **Debugging**: The REPL maintains all variables in memory, making it easier to:
  - Inspect variable values using `@show` or `println`
  - Modify and re-run code without restarting the entire program
  - Use the debugger with `@enter` or `@run`
  - Test small code snippets in isolation

- **Interactivity**: 
  - Plots and graphs automatically open in separate windows
  - Results are immediately visible
  - You can modify parameters and re-run simulations on the fly

## When to Use Scripts

Once your model has been thoroughly debugged and tested in the REPL, you can switch to using scripts for:
- Production runs
- Large-scale optimizations
- Sharing data and models with others

Both workflows can be used interchangeably at this stage, depending on your needs.

In the [next section](@ref "Debugging and Testing a Macro Model"), you'll find several useful methods and utilities for working with new models in Macro.
