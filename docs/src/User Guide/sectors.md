# User Guide
*Macro version 0.1.0*

## Introduction: Energy System in Macro

The Macro model is designed to represent the energy system in a detailed manner, with various sectors and technologies interacting. Each sector is characterized by a **commodity**, a type of energy carrier. The current model includes the following sectors:

- **Electricity**
- **Natural Gas**
- **CO2 and CO2 Capture**
- **Hydrogen**
- **Coal**
- **Biomass**
- **Uranium**

As seen in the [High-level Macro Design](@ref), the energy system is modeled as a *multi-plex network* — a multi-layered network that connects different sectors, and the key components that this network are:

1. **Locations**: Represent geographical locations, each associated with a commodity type.
2. **Demand and supply nodes**: Represent the demand or supply of a commodity at a specific location.
3. **Assets**: Defined as a collection of edges and vertices. See [Macro Asset Library](@ref) for a list of all the assets available in Macro.

In the following sections, we will see how to define the energy system in Macro using the different input files, then we will see what are the different assets and constraints available in Macro, and finally we will see how to run the model and analyze the results.