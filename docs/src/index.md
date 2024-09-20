```@meta
CurrentModule = Macro
```

# Macro

Welcome to the [Macro](https://github.com/macroenergy/Macro) documentation!

## What is Macro?
MAcro-Energy System Capacity Expansion & Resource Optimization Model (MACRO) is a bottom-up, electricity-centric, macro-energy systems optimization model. It is designed to capture capacity investments, operations, and energy flows across and between multiple energy sectors and can be used to explore the impacts of different energy policies, technology costs, and other exogenous factors on the energy system. 

The main features of MACRO include:
- Tailored **Benders decomposition** framework for optimization.
- **Graph-based representation** of the energy system, including nodes, storage units, edges/transmission lines, transformation nodes/conversion units.
- **"Plug and play" flexibility** for integrating various technologies and sectors (e.g., electricity, hydrogen, heat, and transport).
- Technologically rich, **granular temporal resolution** for detailed analysis.
- **Open-source** built using Julia and JuMP.

## Software Manual

```@contents
Pages = [
    "installation.md",
    "sectors.md",
    "assets.md",
    "constraints.md",
    "build_sectors.md",
    "create_example_case.md",
    "type_hierarchy.md",
    "data_model.md",
    "references.md"
]
Depth = 2
```

