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

MacroEnergy.jl (aka Macro) is an open-source framework for multi-sector capacity expansion modeling and analysis of macro-energy systems [@levi2019macro]. It is written in Julia [@bezanson2017julia] and uses the JuMP package [@dunning2017jump] to formulate and solve optimization problems. It enables researchers and practitioners to design and analyze energy and industrial systems that span electricity, fuels, bioenergy, steel, chemicals, and other sectors. The framework is organized around a small set of sector-agnostic components that can be combined into flexible graph structures, making it straightforward to extend tonew technologies, policies, and commodities. Its companion packages support decomposition methods and other advanced techniques, allowing users to scale models across fine temporal and spatial resolutions. MacroEnergy.jl provides a versatile platform for studying energy transitions at the detail and scale demanded by modern research and policy.

# Statement of Need

The increasing complexity of energy systems necessitates advanced modeling tools to support decision-making in infrastructure planning, R&D, and policy design. This complexity comes from the challenge of ensuring the reliability of grids with large amounts of renewable generation and storage, increased coupling and electrification of energy-intensive sectors, greater diversity in the technologies and policies being deployed, and many other factors.

These challenges require modeling frameworks that are both more flexible and more computationally capable than many existing tools. Researchers increasingly need to study energy systems that couple electricity with fuels, hydrogen, heat, industry, and other sectors, while still capturing the spatial and temporal detail needed to represent renewable generation, storage, and infrastructure constraints. MacroEnergy.jl was developed to meet this need. It is designed for researchers and practitioners who want to build and analyze detailed multi-sector models, as well as for modelers and developers who need to extend those models to new sectors, technologies, policies, and formulations.

MacroEnergy.jl was also designed around a layered abstraction, so that different users can work with the framework at different levels of complexity. Users who want to build and run realistic models should not need to engage with the full internal structure of the code, while modelers and developers should still be able to work directly with the framework’s lower-level components when they need to add new assets, sectors, constraints, or methods.

# State of the Field

Capacity expansion modelling frameworks have improved substantially in recent years. A wider range of problems can now be solved thanks to improvements in underlying formulations and solvers, while access to richer data sources has enabled more realistic representations of resources, weather, and demand. Looking ahead, further improvements are on the horizon, including non-linear technology formulations that capture richer trade-offs [@levin2023energy; @falth2023trade; @heo2024effects], tighter integration with integrated assessment models and other tools [@gotske2025first; @gong2023bidirectional; @odenweller2025remind], and novel approaches to scaling up problem size [@pecci2025regularized; @liu2024generalized; @parolin2025sectoral].

At the same time, the field remains split between two broad classes of frameworks. Electricity-centric frameworks, such as PyPSA [@brown2017pypsa], GenX [@jenkins2017enhanced], Calliope [@pfenninger2018calliope], and others [@he2024dolphyn; @Brown_Regional_Energy_Deployment; @howells2011osemosys; @blair2014system], developed the computational capabilities needed to optimize grids over long time series of hourly or sub-hourly data in order to properly represent variable renewable energy generation and storage. In recent years, several have begun extending their frameworks to include additional sectors such as hydrogen, fuels, and industrial processes. On the other hand, economy-wide models such as TIMES [@loulou2005documentation], TEMOA [@hunter2013modeling], and related frameworks have long been able to represent multiple sectors through flexible graph-based structures and broad technology coverage. However, they do not generally provide the computational performance required to include long, high-resolution time series.

There has also been greater agreement on the capabilities that modelling frameworks must provide in order to produce robust, policy-relevant results. Recent studies suggest that capacity expansion models must consider decades of operational data [@ruggles2024planning; @ruhnau2022storage], may require temporal resolution as fine as five minutes [@levin2024high; @mallapragada2018impact], and should capture spatial heterogeneity at the county level [@qiu2024decarbonized; @serpe2025importance; @krishnan2016evaluating; @frysztacki2023inverse]. In addition, they must be able to represent a wide variety of coupled sectors, as much of the remaining decarbonization challenge lies outside the electricity sector.

This creates a gap in the current software landscape. Existing tools tend to provide either the breadth and flexibility needed to represent many sectors, or the computational capabilities needed for high-resolution electricity-system analysis, but not both in the same framework. Extending existing models to new sectors or to dramatically improve performance often requires rewriting core routines or layering new modules on top. This complicates validation, obscures interactions across the system, and leaves the codebase hard to maintain. In the authors’ experience from previous development, frameworks also remain architectured around their original sectors, making it problematic to exclude those sectors and quickly increasing the difficulty and time required to add new features.

MacroEnergy.jl was developed as a fresh framework to address both limitations simultaneously. It combines a sector-agnostic graph-based architecture, similar in spirit to economy-wide frameworks, with a design intended to support the computational methods needed for large, high-resolution, multi-sector analysis.

# Software Design

MacroEnergy.jl is built around a small set of sector-agnostic components that can be combined into graph structures to represent networks, technologies, and policies in any sector. Four core component types: Edges, Nodes, Storage, and Transformations; describe the flow, production, storage, and conversion of commodities. This abstraction allows the same underlying framework to represent electricity, fuels, hydrogen, industrial materials, and other flows without embedding sector-specific logic into the core software. That design makes the framework easier to extend, test, and adapt to new research questions.

A central design choice was to use layered abstraction rather than a single all-or-nothing interface. The four core components can be used directly, but most users will instead work with higher-level abstractions such as Assets, Locations, Systems, and Cases. Assets are collections of components that represent real-world infrastructure, while Locations represent physical places where assets are situated and commodities can be transported between. Systems represent energy and industrial systems over user-defined operating periods, and Cases allow users to organize multiple Systems for workflows such as multi-stage capacity expansion, rolling-horizon optimization, and sensitivity analysis. This layered structure allows beginners to build and run realistic models without engaging with the full internal machinery, while modelers and developers can still work directly with lower-level components when they need additional control.

MacroEnergy.jl was also designed from the ground up to scale to large, multi-sector problems. Modeling across coupled sectors greatly increases runtimes, often making problems intractable [@parolin2025sectoral]. Techniques such as model compression and the use of representative periods can ease the computational burden, but eventually large-scale models reach the limits of what can be solved on a single computing node. To scale further, methods that allow models to be solved across computing clusters are essential. MacroEnergy.jl was designed with these challenges in mind. Its data structures and graph-based representation of energy systems enable sectoral, temporal, and spatial decompositions by default. It also includes a suite of companion packages that provide advanced decomposition algorithms [@pecci2025MacroEnergySolvers], automatic model scaling [@macdonald2024MacroEnergyScaling], and example systems [@macdonald2025MacroEnergyExamples]. Other companion packages are under development and will provide representative period selection and other tools to enhance MacroEnergy.jl.

# Research Impact Statement

MacroEnergy.jl can be used to optimize the design and operation of energy and industrial systems, investigate the value of new technologies or policies, optimize investments in an energy system over multiple years, and support a wide range of related analyses. It is already being used for ongoing multi-sectoral investigations of energy facility design, regional energy systems, and as part of the Net-Zero X Global Initiative, a research consortium of leading institutions that are developing shared modeling methods and completing detailed, actionable country-specific studies supporting net-zero transitions.

The framework is also supported by a broader package ecosystem. MacroEnergy.jl and its companion packages are registered Julia packages and are freely available on GitHub or through the Julia package manager. Companion packages currently provide decomposition algorithms, automatic model scaling, and example systems, which strengthens the framework’s reproducibility and supports near-term research use. As these ongoing studies mature into publications and the companion ecosystem expands, MacroEnergy.jl is positioned to support both methodological research and applied multi-sector energy system analysis.

# Acknowledgements

The development of MacroEnergy.jl was funded by the Schmidt Sciences Foundation. This publication was based (fully or partially) upon work supported by the U.S. Department of Energy’s Office of Energy Efficiency and Renewable Energy (EERE) under the Hydrogen Fuel Cell Technology Office, Award Number DE-EE0010724. The views expressed herein do not necessarily represent the views of the U.S. Department of Energy or the United States Government.

# References
