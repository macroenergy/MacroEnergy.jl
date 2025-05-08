# Macro

**Macro** is a bottom-up, multi-sectoral infrastructure optimization model for macro-energy systems. It co-optimizes the design and operation of user-defined models of multi-sector energy systems and networks. Macro allows users to explore the impact of changing energy policies, technologies, demand patterns, and other factors on an energy system as a whole and as separate sectors.

## Features

The Macro development team have built on their experience developing the [GenX](https://github.com/GenXProject/GenX.jl) and [Dolphyn](https://github.com/macroenergy/Dolphyn.jl) models to develop a new architecture which is easier and faster to expand to new energy technologies, policies, and sectors.

Macro's key features are:

- **Graph-based representation** of the energy system, facilitating clear representation and analysis of energy and mass flows between sectors.
- **"Plug and play" flexibility** for integrating new technologies and sectors, including electricity, hydrogen, heat, and transport.
- **High spatial and temporal resolution** to accurately capture sector dynamics.
- Designed for **distributed computing** to enable large-scale optimizations.
- Tailored **Benders decomposition** framework for optimization.
- **Open-source** built using Julia and JuMP.

## Citing Macro

We are working to publish a peer-reviewed paper describing Macro. In the meantime, please cite this GitHub repository:

```bibtex
@misc{Macro2025,
   author = {Ruaridh Macdonald and Filippo Pecci and Luca Bonaldo and Jun Wen Law and Yu Weng and Sambuddha Chakrabarti and Dharik Mallapragada and Jesse Jenkins},
   month = {5},
   title = {MacroEnergy.jl},
   url = {https://github.com/macroenergy/MacroEnergy.jl},
   year = {2025},
}
```

## Installation

Macro is not currently released as a Julia package, so must be downloaded and installed manually.

To install Macro, please follow the installation instructions in the documentation, [on the Getting Started / Installation page.](https://macroenergy.github.io/MacroEnergy.jl/dev/Getting%20Started/2_installation/)

## Learning to use Macro

### Documentation

The Macro documentation [can be found here.](https://macroenergy.github.io/MacroEnergy.jl/). The documentation contains five main resources:

- A getting started section, which shows you how to install and run Macro.
- Guides, which walk you through how to achieve specfic tasks using Macro.
- A manual, which describes all the components and features of Macro in detail.
- Tutorials, which are extended guides with worked examples
- A function reference, which etails the API and functions available with Macro.

### Bug reports

Please report any bugs or new feature requrests on [the Issues page of this repository](https://github.com/macroenergy/MacroEnergy.jl/issues).
