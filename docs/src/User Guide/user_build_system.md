# Creating a new System

Creating a new System requires several steps:

1. Create a new System
2. Add Commodities and sub-Commodities
3. Add Locations and Nodes
4. Add Assets
5. Add policy Constraints
6. Add asset Constraints

This guide will walk you through the first step and then link to other guides for the subsequent steps.

In these guides, we will discuss building a "System", not a "Model". As a reminder, in Macro the term "System" refers to the real-world system being modelled and optimized while "Model" refers to the mathematical problem which must be solved to optimize the system. Correspondingly, the System object in Macro represents the set of real-world Assets and Locations, while a Model object is the optimization problem handed to the mathematical solver.

## Creating a System

You can create a new System using Macro's template functions. The following function call will create a new System in the "ExampleSystems/template_example" directory, if no such directory exists:

```julia
system = template_system("ExampleSystems/template_example")
```

This function return a System object which can be used to conveniently add more objects, such as Nodes, Assets, and Locations to your System.

If the path provided is already a directory, then the new System will be created at: "ExampleSystems/template_example/new_system". You can specify a different name for the System folder using a second argument:

```julia
system = template_system("ExampleSystems/template_example", "preferred_system_name")
```

This will create a new System at "ExampleSystems/template_example/preferred_system_name".

The template System has the following folder structure:

```
ExampleSystems/template_example
├─ system_data.json
├─ run.jl
├─ assets
├─ settings
|  └─ macro_settings.json
└─ system
   ├─ commodities.json
   ├─ locations.json
   ├─ nodes.json
   └─ time_data.json
```

`system_data.json` tells Macro where to find the data necessary to build the System and Model. The default version matches the template System folder structure. More information about the `system_data.json` can be found here.

## Next steps to creating a System

You now need to populate you System with Locations, Assets, Policies, and other features. These guides will walk you through how to do so:

- [Adding a Commodity to a System](@ref)
- [Adding a Node to a System](@ref)
- [Adding a Location to a System](@ref)
- [Adding an Asset to a System](@ref)
- [Adding policy Constraints to a System](@ref)
- [Adding Asset Constraints to a System](@ref)