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

If you use Macro, please cite the current version of the software and the software paper.

The version citation is available in the "About" section of the GitHub repository.

We have submitted a peer-reviewed paper describing Macro, but please cite the preprint in the meantime:

```bibtex
@article{macdonald2025macroenergy,
  title={MacroEnergy. jl: A large-scale multi-sector energy system framework},
  author={Macdonald, Ruaridh and Pecci, Filippo and Bonaldo, Luca and Law, Jun Wen and Weng, Yu and Mallapragada, Dharik and Jenkins, Jesse},
  journal={arXiv preprint arXiv:2510.21943},
  year={2025}
}
```

## Installation

You can install Macro (aka.MacroEnergy.jl) using the Julia package manager:

```julia
using Pkg
Pkg.add("MacroEnergy")
```

If you wish to make additons to Macro, please follow the installation instructions in the documentation, [on the Getting Started / Installation page.](https://macroenergy.github.io/MacroEnergy.jl/dev/Getting%20Started/2_installation/)

## Recent changes

<!-- BEGIN GENERATED RECENT CHANGES -->
### 0.2.5 - 2026-09-14
#### Fixed

- `StorageChargeLimitConstraint` is now attached to a `Battery`'s charge edge. Before, it was declared as a top-level key in the charge edge's default data instead of inside its `constraints` dictionary, so it was silently dropped.

#### Migration guide

- **Results change:** no public API changed, but any case using a `Battery` asset could now produce different results. The charge limit (`charge_flow[t] <= capacity - storage_level[t-1]`, scaled by the charge efficiency) was previously not included by default and is now enforced. To keep the old behavior, disable it explicitly on the charge edge: `"charge_edge": {"constraints": {"StorageChargeLimitConstraint": false}}`.
- If you set `StorageChargeLimitConstraint` as a top-level key on a charge edge, rather than inside that edge's `constraints` dictionary, it was and still is ignored. Move it inside `constraints` for it to take effect.
- `StorageChargeLimitConstraint` only applies to an edge whose end vertex is the storage, i.e. the charge edge. Setting it on the discharge edge (or via `discharge_constraints` in the simple input format) has no effect.

For the full release history, see [CHANGELOG.md](CHANGELOG.md).
<!-- END GENERATED RECENT CHANGES -->

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
