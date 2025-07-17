# Assets

## Macro Asset Library

Macro is designed to be a flexible and modular model that can adapt to various energy system representations. The model provides a rich library of pre-defined assets, enabling a "plug-and-play" approach for users building their own energy system.

Each asset is defined by a **combination of transformations, edges, and storage units** that represent the physical and operational characteristics of a technology. These assets can be combined to create a detailed representation of the energy system, capturing the interactions between technologies and sectors.

In the following sections, we will introduce each asset type and show the **attributes** that can be set for each of them as well as the **equations** that define the conversion processes. We will also provide a **graphical representation** of the asset in terms of transformations, edges, and storages to help the user understand the structure of the asset.

Each asset page follows a consistent structure with the following sections:

1. **Overview**: A brief description of what the asset represents and its role in energy systems
2. **Asset Structure**: A graphical representation showing the transformations, edges, and storages present in the asset
3. **Flow Equations** (where applicable): Mathematical relationships governing the asset's conversion processes
4. **Input File (Standard Format)**: How to create and configure the asset using JSON or CSV files
5. **Types - Asset Structure**: The Julia type definition and internal structure
6. **Constructors**: The Julia constructors for the asset
7. **Examples**: Practical examples showing different configurations and use cases
8. **Best Practices**: Guidelines for effective asset configuration and usage
9. **Input File (Advanced Format)**: Advanced configuration options and formats

## Available assets
The current library includes the following assets:

- [Battery](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph Battery
  direction BT
    A((Electricity)) e1@-->|Charge| B[Storage]
    B e2@-->|Discharge| A
    e1@{ animate: true }
    e2@{ animate: true }
 end
    style A  r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style B fill:#FFD700,stroke:black,color:black;
    linkStyle 0,1 stroke:#FFD700, stroke-width: 2px;
```

- [BECCS Electricity](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph BECCSElectricity
  direction BT
    B((Biomass)) e1@--> A{{..}}
    C((CO₂ Source)) e2@--> A
    A e5@--> D((Electricity))
    A e3@--> E((Emitted CO₂))
    A e4@--> F((Captured CO₂))
    e1@{ animate: true }
    e2@{ animate: true }
    e3@{ animate: true }
    e4@{ animate: true }
    e5@{ animate: true }
 end
    style A fill:black,stroke:black,color:black;
    style B r:55px,fill:palegreen,stroke:black,color:black, stroke-dasharray: 3,5;
    style C r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
    style D r:55px,fill:#FFD700,stroke:black,color:black, stroke-dasharray: 3,5;
    style E r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
    style F r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;

    linkStyle 0 stroke:palegreen, stroke-width: 2px;
    linkStyle 1,3,4 stroke:lightgray, stroke-width: 2px;
    linkStyle 2 stroke:#FFD700, stroke-width: 2px;
```

- [BECCS Hydrogen](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph BECCSHydrogen
  direction BT
    B((Biomass)) e1@--> A{{..}}
    C((CO₂ Source)) e2@--> A
    D((Electricity)) e3@--> A
    A e4@--> E((Hydrogen))
    A e5@--> F((Emitted CO₂))
    A e6@--> G((Captured CO₂))
    e1@{ animate: true }
    e2@{ animate: true }
    e3@{ animate: true }
    e4@{ animate: true }
    e5@{ animate: true }
    e6@{ animate: true }
 end
    style A fill:black,stroke:black,color:black;
    style B r:55px,fill:palegreen,stroke:black,color:black, stroke-dasharray: 3,5;
    style C r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
    style D r:55px,fill:#FFD700,stroke:black,color:black, stroke-dasharray: 3,5;
    style E r:55px,fill:lightblue,stroke:black,color:black, stroke-dasharray: 3,5;
    style F r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
    style G r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;

    linkStyle 0 stroke:palegreen, stroke-width: 2px;
    linkStyle 1 stroke:lightgray, stroke-width: 2px;
    linkStyle 2 stroke:#FFD700, stroke-width: 2px;
    linkStyle 3 stroke:lightgray, stroke-width: 2px;
    linkStyle 4 stroke:lightgray, stroke-width: 2px;
    linkStyle 5 stroke:lightgray, stroke-width: 2px;
```

- [Electric DAC](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph ElectricDAC
    direction LR
    A((Electricity)) e1@--> C{{..}}
    B((CO₂)) e2@--> C
    C e3@--> D((CO₂ Captured))
    e1@{ animate: true }
    e2@{ animate: true }
    e3@{ animate: true }
  end
  
  style A r:55px,fill:#FFD700,stroke:black,color:black, stroke-dasharray: 3,5;
  style B r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
  style C fill:black,stroke:black,color:black;
  style D r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;

  linkStyle 0 stroke:#FFD700, stroke-width: 2px, stroke-dasharray: 5 5;
  linkStyle 1 stroke:lightgray, stroke-width: 2px;
  linkStyle 2 stroke:lightgray, stroke-width: 2px;
```

- [Electrolyzer](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph Electrolyzer
  direction LR
  A((Electricity)) e1@--> B{{..}}
  B e2@--> C((Hydrogen))
  e1@{ animate: true }
  e2@{ animate: true }
 end
    style A r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style B fill:black,stroke:black,color:black;
    style C r:55px,fill:lightblue,stroke:black,color:black,stroke-dasharray: 3,5;
    linkStyle 0 stroke:#FFD700, stroke-width: 2px, stroke-dasharray: 5 5;
    linkStyle 1 stroke:lightblue, stroke-width: 2px, stroke-dasharray: 5 5;
```

- [Fuel Cell](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph FuelCell
  direction LR
  A((Hydrogen)) e1@--> B{{..}}
  B e2@--> C((Electricity))
  e1@{ animate: true }
  e2@{ animate: true }
 end
    style A r:55px,fill:lightblue,stroke:black,color:black,stroke-dasharray: 3,5;
    style B fill:black,stroke:black,color:black;
    style C r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    linkStyle 0 stroke:lightblue, stroke-width: 2px, stroke-dasharray: 5 5;
    linkStyle 1 stroke:#FFD700, stroke-width: 2px, stroke-dasharray: 5 5;
```

- [Gas Storage](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph GasStorage
  direction LR
    A((Electricity)) e1@--> C{{..}} e2@--> A((Electricity))
    B((Gas)) e3@--> C{{..}} e4@--> B((Gas))
    C e5@--> D[Storage] e6@--> C
    e1@{ animate: true }
    e2@{ animate: true }
    e3@{ animate: true }
    e4@{ animate: true }
    e5@{ animate: true }
    e6@{ animate: true }
 end
    style A r:55px,fill:#FFD700,stroke:black,color:black, stroke-dasharray: 3,5;
    style B r:55px,fill:lightblue,stroke:black,color:black, stroke-dasharray: 3,5;
    style C fill:black,stroke:black,color:black;
    style D fill:lightblue,stroke:black,color:black;

    linkStyle 0,1 stroke:#FFD700, stroke-width: 3px;
    linkStyle 2,3 stroke:lightblue, stroke-width: 3px;
    linkStyle 4,5 stroke:lightblue, stroke-width: 3px;
```

- [Hydro Reservoir](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph HydroRes
    direction LR
    A((Hydro Source)) e1@--> B[Storage] e2@--> C((Electricity))
    B e3@--> A
    e1@{ animate: true }
    e2@{ animate: true }
    e3@{ animate: true }
  end
  
  style A r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
  style B fill:#FFD700,stroke:black,color:black;
  style C r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;

  linkStyle 0 stroke:#FFD700, stroke-width: 2px;
  linkStyle 1 stroke:#FFD700, stroke-width: 2px;
  linkStyle 2 stroke:#FFD700, stroke-width: 2px;
```

- [Must Run](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph MustRun
  direction LR
  A{{..}} e1@--> B((Electricity))
  e1@{ animate: true }
 end
    style A r:55px,fill:black,stroke:black,color:black;
    style B r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    
    linkStyle 0 stroke:#FFD700, stroke-width: 2px, stroke-dasharray: 5 5;
```

- [Natural Gas DAC](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph NaturalGasDAC
    direction BT
    A((Natural Gas)) e1@--> C{{..}}
    B((CO₂)) e2@--> C{{..}}
    C{{..}} e3@--> D((Electricity))
    C{{..}} e4@--> E((CO₂ Emitted))
    C{{..}} e5@--> F((CO₂ Captured))
    e1@{ animate: true }
    e2@{ animate: true }
    e3@{ animate: true }
    e4@{ animate: true }
    e5@{ animate: true }
  end
    style A r:55px,fill:#005F6A,stroke:black,color:white, stroke-dasharray: 3,5;
    style B r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
    style C r:55px,fill:black,stroke:black,color:black, stroke-dasharray: 3,5;
    style D r:55px,fill:#FFD700,stroke:black,color:black, stroke-dasharray: 3,5;
    style E r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
    style F r:55px,fill:lightgray,stroke:black,color:black, stroke-dasharray: 3,5;
    linkStyle 0 stroke:#005F6A, stroke-width: 2px;
    linkStyle 1 stroke:lightgray, stroke-width: 2px;
    linkStyle 2 stroke:#FFD700, stroke-width: 2px;
    linkStyle 3 stroke:lightgray, stroke-width: 2px;
    linkStyle 4 stroke:lightgray, stroke-width: 2px;
```

- [Transmission Link](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph TransmissionLink
  direction LR
    A((Commodity)) e1@-->|Transmission| B((Commodity))
    e1@{ animate: true }
 end
    style A r:40,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style B r:40,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    linkStyle 0 stroke:#FFD700, stroke-width: 2px;
```

- [Thermal Hydrogen Plant (with and without CCS)](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph ThermalHydrogen
    direction BT
    A((Fuel)) e1@--> C{{..}}
    B((Electricity)) e2@--> C{{..}}
    C{{..}} e3@--> D((Hydrogen))
    C{{..}} e4@--> E((CO₂ Emitted))
    C{{..}} e5@--> F((CO₂ Captured))
    e1@{ animate: true }
    e2@{ animate: true }
    e3@{ animate: true }
    e4@{ animate: true }
    e5@{ animate: true }
  end
  
  style A r:55px,fill:#005F6A,stroke:black,color:white,stroke-dasharray: 3,5;
  style B r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
  style C r:55px,fill:black,stroke:black,color:black, stroke-dasharray: 3,5;
  style D r:55px,fill:lightblue,stroke:black,color:black,stroke-dasharray: 3,5;
  style E r:55px,fill:lightgray,stroke:black,color:black,stroke-dasharray: 3,5;
  style F r:55px,fill:lightgray,stroke:black,color:black,stroke-dasharray: 3,5;

  linkStyle 0 stroke:#005F6A, stroke-width: 2px;
  linkStyle 1 stroke:#FFD700, stroke-width: 2px;
  linkStyle 2 stroke:lightblue, stroke-width: 2px;
  linkStyle 3,4 stroke:lightgray, stroke-width: 2px;
```

- [Thermal Power Plant (with and without CCS)](@ref)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph ThermalPower
  direction BT
  A((Fuel)) e1@ --> B{{..}}
  B e2@ --> C((Electricity))
  B e3@ --> D((CO₂))
  B e4@ --> E((CO₂Captured))
  e1@{animate: true}
  e2@{animate: true}
  e3@{animate: true}
  e4@{animate: true}
 end
    style A r:55px,fill:#005F6A,stroke:black,color:white,stroke-dasharray: 3,5;
    style B r:55px,fill:black,stroke:black,color:black,stroke-dasharray: 3,5;
    style C r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style D r:55px,fill:lightgray,stroke:black,color:black,stroke-dasharray: 3,5;
    style E r:55px,fill:lightgray,stroke:black,color:black,stroke-dasharray: 3,5;
  linkStyle 0 stroke:#005F6A, stroke-width: 2px;
  linkStyle 1 stroke:#FFD700, stroke-width: 2px;
  linkStyle 2 stroke:lightgray, stroke-width: 2px;
  linkStyle 3 stroke:lightgray, stroke-width: 2px;
```

- [Variable Renewable Energy resources (VRE)](@ref vre)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph VRE
  direction LR
  A((Energy Source)) e1@--> B{{..}}
  B e2@--> C((Electricity))
  e1@{ animate: true }
  e2@{ animate: true }
 end
    style A r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style B r:55px,fill:black,stroke:black,color:black,stroke-dasharray: 3,5;
    style C r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    linkStyle 0 stroke:#FFD700, stroke-width: 2px;
    linkStyle 1 stroke:#FFD700, stroke-width: 2px;
```
