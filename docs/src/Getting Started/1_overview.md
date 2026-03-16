# Getting Started

This getting started guides aims to help you:

- [Understand how you can use Macro](@ref "How can I use Macro?")
- [Get a high-level understanding of how real-world systems are modeled in Macro](@ref "How are real-world systems represented in Macro?")
- [Install Macro](@ref "Installation")
- [Expore the files included with Macro](@ref "What is in the Macro repo?")
- [Run your first case](@ref "Running Macro")

## How can I use Macro?

Macro can be used in a variety of ways to optimize the design and operation of energy and industrial systems, investigate the value of new technologies or polices, optimize investments in an energy system over multiple years, and many more. Some example workflows are given below:

### Optimizing an energy system

Creating and running a model with Macro can be done without knowing Julia programming. A typical workflow with Macro consists of the following:

1. Collect the data required for your model, including supply and demand of different commodities, and cost and performance data for available production and storage Assets.
2. [Create a Macro System](@ref "Creating a new System") and add the Assets and Locations required to represent your real-world system. Import your data into your System.
3. [Add policy constraints to your System.](@ref "Adding Policy Constraints to a System")
4. [Configure the settings for your System.](@ref "Configuring Settings")
5. [Run your case](@ref "Running a Macro Model"), to optimize the design and operation of your System.
6. Analyze the results.

From there you might run a sensitivity study on your results by changing some of your input data, adding or removing an Asset, or changing one of System policies.

### Adding a new sector

While Macro includes a variety of sector models and Assets; representing real-world production, storage, and transport technologies; you may want to create new Assets or sectors for your project. Doing so will require some Julia programming, but no detailed knowledge of the packages underlying Macro.

To create a new sector, you will need to:

1. Create any new Commodities that your sector will require. These Comodities can be energy, material, data, or flows which are important in your new sector.
2. Create new Assets to represent production, storage, transport, and end-use technologies in your sector. At least some of these should produce, store, transport, and consume your new Commodities.
3. Assign default inputs for your Assets and specifiy which inputs are optional vs. required.

## Helpful packages

There are several packages we recommend to improve the speed and quality of your work with Macro.

[MacroEnergySolvers.jl](https://github.com/macroenergy/MacroEnergySolvers.jl) : includes several advanced algorithms for solving Macro models. This includes decompositions, multi-stage models, and sensitivity studies.

[MacroEnergyScaling.jl](https://github.com/macroenergy/MacroEnergyScaling.jl) : can be used to improve the numerical stability of Macro models, improving runtime and the accuracy of your results.

[The manual includes more details on these and other useful packages.](@ref "Related Packages")

Please let us know if you are working on something (Julia-based or otherwise) which could be included in this list!

## How are real-world systems represented in Macro?

### Multi-commodity flow network

Macro Systems are **multi-commodity flow networks**. Commodities can be energy, material, data, or other products of interest. Macro Systems consist of Vertices, where Commodities are produced, stored, and consumed; and Edges, which Commodities can flow along. With just these few elements, you can model complex real-world systems using Macro.

While you could describe your real-world system in terms of Macro Vertices and Edges, such a system would be quite abstract and may not be intuitive. Therefore, Macro allows you to build your System from **Locations** and **Assets**. These are collections of Vertices and Edges which correspond more closely to elements of read-world systems.

#### 1. Locations

Locations represent geographic places or areas. They are made up of Nodes, which each carry one Commodity and can be used to define external **supply** and/or **demand** of that Commodity. Each location can only contain a single Node for each Commodity.

To add a Locations to a System, you must [define the constituent Nodes](@ref "Adding a Node to a System") and [add the Location to list of Locations.](@ref "Adding a Location to a System"). These two links will take you to the Guides on how to do both tasks.

#### 2. Assets

Assets in Macro represent means of producing, storing, transporting, and consuming one or more Commodities. Assets can be sited at a Location, so your Macro System will intuitively represent real-world systems. For example, an Asset can define a power plant that converts a fuel into electricity, which is then assigned to a Location, linking it to the electricity and fuel Nodes at that Location. Each Asset is characterized by a list of Commodities they take as input and output and technical and a range of economic and techical parameters.

Macro has a rich library of Assets already designed and implemented. [You can also create your own Assets.](@ref modeler_create_asset) These can be used just for your project or you can [add it to Macro for others to use](@ref how_to_contribute).

Some examples of of assets are:

- Pipelines or power lines
- Thermal power plants (e.g. natural gas/coal/nuclear power plants with and without carbon capture)
- Batteries and hydrogen storage
- Hydroelectric reservoirs
- Variable renewable energy sources (e.g. wind turbines, solar panels)
- Electrolyzers
- Steam methane reformers
- Run-of-river, reservoir storage and pumped storage hydro-electric facilities
- Biorefineries

!!! note
    Pipelines and power lines connecting locations are also considered assets as they can transport, store and transform/compress commodities.

The [Macro Asset Library](@ref) contains the list of all Assets available in Macro.
