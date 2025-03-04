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

The energy system is modeled as a *multi-plex network* — a multi-layered network that connects different sectors.

The key components of this network are:

1. **Vertices**: Represent **balance equations** and can correspond to transformations (linking two or more commodity networks), storage systems, or demand nodes (outflows):
    - **Transformations**: 
        - Special vertices that **convert** one commodity type into another, acting as bridges between sectors. 
        - They represent conversion processes defined by a set of **stoichiometric equations** specifying transformation ratios.
    - **Storage**: 
        - Stores commodities for future use.
        - The flow of commodities into and out of storage systems is regulated by **Storage balance** equations.
    - **Nodes**:
        - Represent geographical locations or zones, each associated with a commodity type.
        - They can be of two types: demand nodes (outflows) or sources (inflows).
        - **Demand balance** equations are used to balance the flow of commodities into and out of the node.
        - They form the network for a specific sector (e.g., electricity network, hydrogen network, etc.).
2. **Edges**: 
    - Depict the **flow** of a commodity into or out of a vertex.
    - Capacity sizing decisions, capex/opex, planning and operational constraints are associated with the edges.
3. **Assets**: Defined as a collection of edges and vertices. See [Macro Asset Library](@ref) for a list of all the assets available in Macro.

The figure below illustrates a multi-plex network representing an energy system with electricity, natural gas, and CO2 sectors, with two natural gas power plants, and a solar panel. Blue nodes represent the electricity sector, red nodes represent natural gas, and yellow nodes represent CO2. The edges depict commodity flow, and squares represent transformation points.

![Energy System](../images/network.png)