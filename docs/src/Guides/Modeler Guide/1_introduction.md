# Modeler Guides

This section of the documentation is designed to provide an overview of the internal representation of **Locations** and **Assets** to help modelers create new sectors and assets. 


## Multi-commodity flow network
As mentioned in the [Getting Started](@ref) section, Macro is designed to represent energy systems in a detailed manner, capturing interactions among various sectors and technologies. 
The internal representation of the energy system is structured as a **multi-commodity flow network**, with each commodity having independent spatial and temporal scale:

![multi-commodity flow network](../../images/multi_network.png)

As an example, the figure above illustrates a multi-plex network representing an energy system with electricity, natural gas, hydrogen and CO2 sectors, with a natural gas power plant, an electrolyzer, a DAC module and an SMR with carbon capture. Orange nodes represent the demand nodes in the electricity sector, maroon nodes represent natural gas nodes, blue nodes represent hydrogen, grey nodes represent CO2 and purple nodes represent CO2 capture nodes. The edges depict commodity flow, and squares represent transformation points.

As illustrated in the figure above, the core components of the model are:

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

Macro includes a library of assets (see [Macro Asset Library](@ref)) and constraints (see [Macro Constraint Library](@ref)), enabling **fast** and **flexible assembly** of new technologies and sectors.

In the following sections, we will describe how to create new sectors, assets as well as how to debug and test the new system.