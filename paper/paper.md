---
title: 'MacroEnergy.jl: A large-scale multi-sector energy system model'

tags:
  - Julia
  - energy
  - energy systems
  - infrastructure planning
  - capacity expansion
  - optimization
authors:
  - name: Ruaridh R. Macdonald
    orcid: 0000-0001-9034-6635
    corresponding: true
    equal-contrib: true
    affiliation: 1
  - name: Filippo Pecci
    orcid: 0000-0003-3200-0892
    equal-contrib: true
    affiliation: 2
  - name: Luca Bonaldo
    orcid: 0009-0000-0650-0266
    equal-contrib: true
    affiliation: 3
  - name: Jun Wen Law
    orcid: 0009-0001-8766-3100
    equal-contrib: true
    affiliation: 1
  - name: Anna X. Li
    orcid: 0000-0002-3435-3651
    affiliation: 3
  - name: Chaitanya Vuppanapalli
    orcid: 0009-0003-6893-6366
    affiliation: 4
  - name: Emil Dimanchev
    orcid: 0000-0001-8240-5922
    affiliation: 4
  - name: Jonah Langleib
    orcid: 0000-0002-9949-1123
    affiliation: 4
  - name: Ruike Lyu
    orcid: 0000-0003-3749-1117
    affiliation: 3
  - name: Sambuddha Chakrabarti
    orcid: 0000-0002-8916-5076
    affiliation: 3
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

MacroEnergy.jl (aka Macro) is an open-source framework for multi-sector capacity expansion modeling. It is written in Julia and uses the JuMP package to interface with a wide range of mathematical solvers. It enables researchers and practitioners to design and analyze energy and industrial systems that span electricity, fuels, heat, transport, and other sectors. The framework is organized around a small set of sector-agnostic components that can be combined into flexible graph structures, making it straightforward to extend to new technologies, policies, and commodities. Its companion packages support decomposition methods and other advanced techniques, allowing users to scale models across fine temporal and spatial resolutions. MacroEnergy.jl provides a versatile platform for studying energy transitions at the detail and scale demanded by modern research and policy.

# Statement of Need

The increasing complexity of energy systems necessitates advanced modeling tools to support decision-making in infrastructure planning, R&D decisions and policy design. This complexity comes from the challenge of ensuring the reliability of grids with large amounts of renewable generation and storage, increased coupling and electrification of energy-intensive sectors, greater diversity in the technologies and policies being deployed, and many other factors.
 
Capacity expansion modelling frameworks; including PyPSA, TIMES, GenX, Calliope, Dolphyn, and others [REF: ReEDS, OSeMOSYS, SAM, TEMOA]; have improved substantially in recent years. A wider range of problems can now be solved thanks to improvements in the underlying formulations and solvers while access to richer data sources has enabled more realistic representations of resources, weather and demand. Looking ahead, further improvements are on the horizon, including non-linear technology formulations that capture richer trade-offs, tighter integration with integrated assessment models and other tools, and novel approaches to scaling up problem size. Despite this progress, most modeling frameworks remain centered on the electricity sector. To answer the next set of questions about the energy transition, frameworks must be able to accommodate a wide variety of technologies and policies which reach across sectors.
 
Most frameworks were built with one or a few sectors in mind, usually electricity. Extending them to new sectors often requires rewriting core routines or layering new modules on top, which complicates validation, obscures interactions across the system, and leaves the codebase hard to maintain. In addition, models remain architectured around their original sectors, making it problematic to exclude those sectors and quickly increasing the difficult and time required to add new features.
 
MacroEnergy.jl was designed to overcome these limitations. Its architecture is based on a small set of sector-agnostic components that can be combined into graphs to represent networks, technologies, and policies in any sector. Features are largely independent of one another, allowing users to focus on how best to represent their technology or policy of interest, instead of working around the existing code.
 
Modeling across coupled sectors greatly increases runtimes, often making problems intractable [REF: Parolin, 2025]. At the same time, recent studies suggest that robust electricity grid design requires models that span decades of operational data, resolve temporal dynamics at intervals as short as five minutes, and capture spatial heterogeneity at the county level. Techniques such as model compression and the use of representative periods can ease the computational burden, but eventually large-scale models reach the limits of what can be solved on a single computing node. To scale further, decomposition methods are essential. MacroEnergy.jl was designed with these challenges in mind. It’s data structures and graph-based representation of energy systems makes decompositions straightforward. It also has a suite a companion packages [REF] with decomposition algorithms and other tools to reduce runtimes. These design choices make high-resolution, multi-sector analysis computationally practical.

# Use Cases

MacroEnergy.jl can be used to optimize the design and operation of energy and industrial systems, investigate the value of new technologies or polices, optimize investments in an energy system over multiple years, and many other tasks. It is being used for several ongoing investigations of regional energy systems as part of the Net-Zero X Global Initiative.

The framework was designed with three user profiles in mind. Where possible, we have passed modelling complexity upstream to developers, so that most users can build and run models faster and with less coding knowledge.

- Users: Want to create and optimize a real-world system using MacroEnergy.jl. They should be able to do this with little or no coding, and without knowledge of MacroEnergy.jl’s components or internal structure.

- Modelers: Want to add new assets, sectors, or public policies to MacroEnergy.jl. They will need to be able to code in Julia and understand some of MacroEnergy.jl’s components, but they do require knowledge of its internal structure or underlying packages.

- Developers: Want to change or add new features, model formulations or constraints to MacroEnergy.jl. They will require detailed knowledge of MacroEnergy.jl’s components, internal structure, and underlying packages.

# Structure

MacroEnergy.jl models are made up for four core components which are used to describe the production, transport, storage and consumption of various commodities. The components can be connected into multi-sectoral networks of commodities. They are commodity-agnostic so can be used for any flow of a good, energy, etc. While we believe MacroEnergy.jl will most often be used to study energy systems, commodities can also be data, goods, money, or more abstract flows.

The four core components are:

1. Edges: describe and constrain the flow of a commodity

2. Nodes: balance flows of one commodity and allow for exogenous flows into and out of a model. These can be used to represent demand or supply of a commodity.

3. Storage: allow for a commodity to be stored over time.

4. Transformations: allow for the conversion of one commodity into another by balancing flows of one or more commodities.

These four core components can be used directly but most users will find it easier to combine them into Assets and Locations. These represent infrastructure and physical places respectively and allow for models to be truer to life and easier to analyze.
 
Together, Assets and Locations form Systems which represent an energy system. Most often, each System will be optimized separately given a user-defined operating period. Several Systems can be combined into a Case. Cases can be used for multi-stage capacity expansion models, rolling-horizon optimization, sensitivity studies, and other work requiring multiple snapshots or versions of an energy system.

# Acknowledgements

The development of MacroEnergy.jl was funded the Schmidt Sciences Foundation. Individual contributors were also funded by 

-- **Please fill in your funding sources**. -- 

# References