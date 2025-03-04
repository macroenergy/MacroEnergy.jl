```@meta
CurrentModule = MacroEnergy
```

# Macro

### Welcome to the [Macro](https://github.com/macroenergy/MacroEnergy.jl.git) documentation!

## What is Macro?

**Macro** is a bottom-up, electricity-centric, macro-energy systems optimization model. It is designed to capture capacity investments, operations, and energy flows across and between multiple energy sectors and can be used to explore the impacts of different energy policies, technology costs, and other exogenous factors on the energy system. 

The main features of Macro include:
- Tailored **Benders decomposition** framework for optimization.
- **Graph-based representation** of the energy system, including nodes, storage units, edges/transmission lines, transformation nodes/conversion units.
- **"Plug and play" flexibility** for integrating various technologies and sectors (e.g., electricity, hydrogen, heat, and transport).
- Technologically rich, **granular temporal resolution** for detailed analysis.
- **Open-source** built using Julia and JuMP.

## Macro development strategy

Macro has been designed and developed with three layers of abstractions in mind, each serving a different kind of user:

![Macro architecture](./images/macro_abstr_layers.png)

The following sections of the documentation are designed to serve the different needs of the different users:
- [User Guide](@ref)
- [Modeler Guide](@ref)
- [Developer Guide](@ref)

## Index

```@contents
Pages = [
    "Getting Started/overview.md",
    "Getting Started/installation.md",
    "Tutorials/tutorial_0_getting_started.md",
    "Tutorials/tutorial_1_input_file.md",
    "Tutorials/tutorial_2_running_macro.md",
    "Tutorials/tutorial_3_multisector_modelling.md",
    "User Guide/sectors.md",
    "User Guide/input_data.md",
    "User Guide/assets/introduction.md",
    "User Guide/assets/battery.md",
    "User Guide/assets/beccselectricity.md",
    "User Guide/assets/beccshydrogen.md",
    "User Guide/assets/electricdac.md",
    "User Guide/assets/electrolyzer.md",
    "User Guide/assets/fuelcell.md",
    "User Guide/assets/gasstorage.md",
    "User Guide/assets/hydrogenline.md",
    "User Guide/assets/hydropower.md",
    "User Guide/assets/mustrun.md",
    "User Guide/assets/natgasdaq.md",
    "User Guide/assets/powerline.md",
    "User Guide/assets/thermalhydrogen.md",
    "User Guide/assets/thermalpower.md",
    "User Guide/assets/vre.md",
    "User Guide/constraints.md",
    "Modeler Guide/build_sectors.md",
    "Modeler Guide/create_example_case.md",
    "Developer Guide/type_hierarchy.md",
    "References/references.md"
]
Depth = 2
```

