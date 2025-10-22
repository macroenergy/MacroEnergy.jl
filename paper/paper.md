---
title: 'MacroEnergy.jl: A large-scale multi-sector energy system framework'

tags:
  - Julia
  - energy
  - energy systems
  - infrastructure planning
  - capacity expansion
  - optimization
authors:
  - name: Ruaridh Macdonald
    orcid: 0000-0001-9034-6635
    corresponding: true
    affiliation: 1
  - name: Filippo Pecci
    orcid: 0000-0003-3200-0892
    affiliation: 2
  - name: Luca Bonaldo
    orcid: 0009-0000-0650-0266
    affiliation: 3
  - name: Jun Wen Law
    orcid: 0009-0001-8766-3100
    affiliation: 1
  - name: Yu Weng
    orcid: 0000-0003-3958-1546
    affiliation: 1
  - name: Dharik Mallapragada
    orcid: 0000-0002-0330-0063
    affiliation: 4
  - name: Jesse Jenkins
    orcid: 0000-0002-9670-7793
    affiliation: 3
affiliations:
 - name: Massachusetts Institute of Technology, USA
   index: 1
 - name: RFF-CMCC European Institute on Economics and the Environment, Italy
   index: 2
 - name: Princeton University, USA
   index: 3
 - name: New York University, USA
   index: 4
date: 21 August 2025
bibliography: paper.bib
---

# Summary

MacroEnergy.jl (aka Macro) is an open-source framework for multi-sector capacity expansion modeling and analysis of macro-energy systems[@levi2019macro]. It is written in Julia [@bezanson2017julia] and uses the JuMP [@dunning2017jump] package to interface with a wide range of mathematical solvers. It enables researchers and practitioners to design and analyze energy and industrial systems that span electricity, fuels, bioenergy, steel, chemicals, and other sectors. The framework is organized around a small set of sector-agnostic components that can be combined into flexible graph structures, making it straightforward to extend to new technologies, policies, and commodities. Its companion packages support decomposition methods and other advanced techniques, allowing users to scale models across fine temporal and spatial resolutions. MacroEnergy.jl provides a versatile platform for studying energy transitions at the detail and scale demanded by modern research and policy.

# Statement of Need

The increasing complexity of energy systems necessitates advanced modeling tools to support decision-making in infrastructure planning, R&D decisions and policy design. This complexity comes from the challenge of ensuring the reliability of grids with large amounts of renewable generation and storage, increased coupling and electrification of energy-intensive sectors, greater diversity in the technologies and policies being deployed, and many other factors.

Capacity expansion modelling frameworks have improved substantially in recent years. A wider range of problems can now be solved thanks to improvements in the underlying formulations and solvers while access to richer data sources has enabled more realistic representations of resources, weather and demand. Looking ahead, further improvements are on the horizon, including non-linear technology formulations that capture richer trade-offs [@levin2023energy; @falth2023trade; @heo2024effects], tighter integration with integrated assessment models and other tools [@gotske2025first; @gong2023bidirectional; @odenweller2025remind], and novel approaches to scaling up problem size [@pecci2025regularized; @liu2024generalized; @parolin2025sectoral].

There has also been some convergence in the design and capabilities of modelling frameworks as the field comes to understand what is required to produce robust, policy-relevant results. Recent studies suggest that capacity expansion models must consider decades of operational data [@ruggles2024planning; @ruhnau2022storage], may require temporal resolution as fine as five minutes [@levin2024high; @mallapragada2018impact], and should capture spatial heterogeneity at the county level [@qiu2024decarbonized; @serpe2025importance; @krishnan2016evaluating; @frysztacki2023inverse]. In addition, they must be able to represent a wide variety of coupled sectors as the majority of emission reductions will come from outside the electricity sector. Electricity-centric frameworks; such as PyPSA [@brown2017pypsa], GenX [@jenkins2017enhanced], Calliope [@pfenninger2018calliope], and others [@he2024dolphyn; @Brown_Regional_Energy_Deployment; @howells2011osemosys; @blair2014system]; developed the computational capabilities needed to optimize grids over long time series of hourly or sub-hourly data in order to properly incorporate variable renewable energy generation and storage. In recent years, several have begun to extending their frameworks to include other sectors, such as hydrogen, fuels, and industrial processes. On the other hand, economy-wide models; such as TIMES [@loulou2005documentation], TEMOA [@hunter2013modeling] and others; have long been able to represent multiple sectors though the use of flexible graph-based structures. However, they do not have the computational performance required to include long, high-resolution time series.

Extending existing models to new sectors or to dramatically improve performance often requires rewriting core routines or layering new modules on top. This complicates validation, obscures interactions across the system, and leaves the codebase hard to maintain. In the authors' experience from previous development, the frameworks remain architectured around their original sectors, making it problematic to exclude those sectors and quickly increasing the difficulty and time required to add new features.

MacroEnergy.jl was designed to overcome these limitations. Its architecture is based on a small set of sector-agnostic components that can be combined into graphs to represent networks, technologies, and policies in any sector. Features are largely independent of one another, allowing users to focus on how best to represent their technology or policy of interest instead of working around the existing code.

MacroEnergy.jl is also designed from the ground-up to scale to large, multi-sector problems. Modeling across coupled sectors greatly increases runtimes, often making problems intractable [@parolin2025sectoral]. Techniques such as model compression and the use of representative periods can ease the computational burden, but eventually large-scale models reach the limits of what can be solved on a single computing node. To scale further, methods which allow models to be solved across computing clusters are essential. MacroEnergy.jl was designed with these challenges in mind. Its data structures and graph-based representation of energy systems enable sectoral, temporal and spatial decompositions by default. It also includes a suite of companion packages, which provide advanced decomposition algorithms [@pecci2025MacroEnergySolvers], automatic model scaling [@macdonald2024MacroEnergyScaling], and example systems [@macdonald2025MacroEnergyExamples]. Other companion packages are under development. These will provide representative period selection and other tools to enhance MacroEnergy.jl. MacroEnergy.jl and its companion packages are registered Julia packages and are freely available on GitHub or through the Julia package manager.

# Use Cases

MacroEnergy.jl can be used to optimize the design and operation of energy and industrial systems, investigate the value of new technologies or polices, optimize investments in an energy system over multiple years, and many other tasks. It is being used for several ongoing investigations of regional energy systems, including as part of the Net-Zero X Global Initiative - a research consortium involving top research institutions around the world developing shared modeling methods and completing detailed, actionable country-specific studies supporting net-zero transitions.

The framework was designed with three user profiles in mind. Where possible, we have passed modelling complexity upstream to developers, so that most users can build and run models faster and with less coding knowledge.

- Users: Want to create and optimize a real-world system using MacroEnergy.jl. They should be able to do this with little or no coding, and without knowledge of MacroEnergy.jl’s components or internal structure.

- Modelers: Want to add new assets, sectors, or public policies to MacroEnergy.jl. They will need to be able to code in Julia and understand some of MacroEnergy.jl’s components, but they do not require knowledge of its internal structure or underlying packages.

- Developers: Want to change or add new features, model formulations or constraints to MacroEnergy.jl. They will require detailed knowledge of MacroEnergy.jl’s components, internal structure, and underlying packages.

# Structure

MacroEnergy.jl models are made up of four core components which are used to describe the production, transport, storage and consumption of various commodities. The components can be connected into multi-sectoral networks of commodities. They are commodity-agnostic so can be used for any flow of a good, energy, etc. While we believe MacroEnergy.jl will most often be used to study energy systems, commodities can also be data, money, or more abstract flows.

The four core components are:

1. Edges: describe and constrain the flow of a commodity

2. Nodes: balance flows of one commodity and allow for exogenous flows into and out of a model. These can be used to represent exogenous demand or supply of a commodity.

3. Storage: allow for a commodity to be stored over time.

4. Transformations: allow for the conversion of one commodity into another by balancing flows of one or more commodities.

These four core components can be used directly to build models but most users will find it easier to combine them into Assets and Locations. Assets are collections of components that represent real-world infrastructure such as power plants, industrial facilities, transmission lines, etc. For example, a water electrolyzer asset would include edges for electricity and water inputs and hydrogen output, and a transformation to conver between them. Locations are collections of Nodes which represent physical places where assets are situated and commodities can be transported between. While Edges can only connect to Nodes of the same Commodity, Locations are an abstraction that simplifies the user-input required to connect different commodities across physical places. Together, Assets and Locations allow for models to be truer to life and easier to analyze.

Assets and Locations in turn form Systems which represent an energy and/or industrial system. Most often, each System will be optimized separately given a user-defined operating period. Several Systems can be combined into a Case. Cases can be used for multi-stage capacity expansion models, rolling-horizon optimization, sensitivity studies, and other work requiring multiple snapshots or versions of an energy system. MacroEnergy.jl can automatically manage the running of these different Cases for users, either directly or in combination with MacroEnergySolver.jl package.

# Acknowledgements

The development of MacroEnergy.jl was funded by the Schmidt Sciences Foundation. This publication was based (fully or partially) upon work supported by the U.S. Department of Energy’s Office of Energy Efficiency and Renewable Energy (EERE) under the Hydrogen Fuel Cell Technology Office, Award Number DE-EE0010724. The views expressed herein do not necessarily represent the views of the U.S. Department of Energy or the United States Government.

# References