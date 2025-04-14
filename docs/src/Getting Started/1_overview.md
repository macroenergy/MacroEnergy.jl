# Getting Started

**Macro version 0.1.0**

## High-level Macro Design

### Multi-commodity flow network

Macro is designed to represent energy systems in a detailed manner, capturing interactions among various sectors and technologies. At high level, the model is structured as a **multi-commodity flow network**, with each commodity having independent spatial and temporal scale. The three main components of the model are:

1. **Locations**
2. **Assets**

### Energy system components

#### 1. Locations

They represent geographical locations, containing the **demand** or **supply** (node) for different commodities. In the current version of Macro, each location can only contain a single node per commodity type. 
Adding locations to a system is straightforward, the user only needs to specify a list of names in the `locations.json` input file. For example:

```json
"locations": [
    "SE",
    "MIDAT",
    "NE"
]
```

Users can add nodes of different commodity types to a location using the `nodes.json` input file. This file also contains the parameters specifying the time series of the commodity demand/supply at each node, price for non-served demand, commodity type and location. Please refer to the [Macro Input Data](@ref) section for more details.

#### 2. Assets

Assets in Macro represent generic **technologies** at a specific location that transforms, transports or stores one or more commodities. Macro has a rich library of assets already modelled, including power lines, pipelines, power plants, electrolyzers, vres, etc.
Each asset is characterized by a set of parameters, including the list of commodities they take as input and output, as well as all the technical and economic parameters that characterize the technology and regulate the conversion processes.

!!! note
    Pipelines and power lines connecting locations are also considered assets as they can transport, store and transform/compress commodities.

Examples of assets are (see [Macro Asset Library](@ref) for a list of all the assets available in Macro):
- Pipelines or power lines
- Power plants (e.g. natural gas/coal/nuclear power plants with and without carbon capture)
- Batteries and hydrogen storage
- Hydroelectric reservoirs
- Variable renewable energy sources (e.g. wind turbines, solar panels)
- Electrolyzers
- SMRs
- Pumped hydro storage
- Biorefineries




