```@meta
CurrentModule = MacroEnergy
```

# Macro

### Welcome to the [Macro](https://github.com/macroenergy/MacroEnergy.jl.git) documentation!

## What is Macro?

**Macro** is a bottom-up, multi-sectoral infrastructure optimization model for macro-energy systems. It co-optimizes the design and operation of user-defined models of multi-sector energy systems and networks. Macro allows users to explore the impact of energy policies, technology costs and performance, demand patterns, and other factors on an energy system as a whole and as separate sectors.

The main features of Macro include:

- **Graph-based representation** of the energy system, facilitating clear representation and analysis of energy and mass flows between sectors.
- **"Plug and play" flexibility** for integrating new technologies and sectors, including electricity, hydrogen, heat, and transport.
- **High spatial and temporal resolution** to accurately capture sector dynamics.
- Designed for **distributed computing** to enable large-scale optimizations.
- Tailored **Benders decomposition** framework for optimization.
- **Open-source** built using Julia and JuMP.

## Macro development strategy

Macro is a very flexible tool for modelling energy systems. However, that flexibility also means the core architecture and functions are complex and difficult to use correctly.

To make Macro as useful and accessible to the widest audience possible we designed and developed it with three layers of abstractions in mind, each serving a different user profile:

![Macro architecture](./images/macro_abstr_layers.png)

The following sections of the documentation are designed to serve the different needs of the different users.

## Structure of the documentation

- ### [Getting Started](@ref)

- ### [User Guide](@ref)

- ### [Modeler Guide](@ref)

- ### [Developer Guide](@ref)

## [Table of contents](@ref)
