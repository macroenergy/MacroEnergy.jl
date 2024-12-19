# Macro Asset Library

Macro is designed to be a flexible and modular model that can adapt to various energy system representations. The model includes a library of assets that represent different technologies within the energy system.

Each asset is defined by a **combination of transformations, edges, and storage units** that represent the physical and operational characteristics of a technology. These assets can be combined to create a detailed representation of the energy system, capturing the interactions between technologies and sectors.
For instance, a **natural gas power plant** asset consists of a technology that converts natural gas into electricity while producing CO2 emissions. This asset includes:

- A **transformation vertex** representing the conversion process: `Natural Gas -> Electricity + CO2`,
- An incoming **edge** for natural gas supply,
- An outgoing **edge** for electricity production, and
- A second outgoing edge for **CO2 emissions**.

All other assets in the library follow a similar structure, with specific transformations, edges, and storage units based on their respective technologies.

## Asset Library
The current library includes the following assets:

- **Battery**

```@raw html
<img width="270" src="../images/battery.png" />
```

- **Electrolyzer**

```@raw html
<img width="360" src="../images/electrolyzer_asset.png" />
```

- **Fuel Cell**

```@raw html
<img width="320" src="../images/fuelcell.png" />
```

- **Gas Storage**

```@raw html
<img width="400" src="../images/hydrogen_storage.png" />
```

- **Thermal Hydrogen Plant**

```@raw html
<img width="360" src="../images/smr.png" />
```

- **Thermal Power Plant**

```@raw html
<img width="380" src="../images/natgas.png" />
```

- **Variable Renewable Energy resources (VRE)**

```@raw html
<img width="300" src="../images/vre.png" />
```

- **BECCS Electricity**

```@raw html
<img width="400" src="../images/beccselec.png" />
```

- **BECCS Hydrogen**

```@raw html
<img width="400" src="../images/beccsh2.png" />
```

- **Electric DAC**

```@raw html
<img width="360" src="../images/elecdac.png" />
```

- **Hydro Res**

```@raw html
<img width="360" src="../images/hydrores.png" />
```

- **Natural Gas DAC**

```@raw html
<img width="450" src="../images/natgasdac.png" />
```

- **Power Line**

```@raw html
<img width="220" src="../images/powerline.png" />
```

- **Hydrogen Line**

```@raw html
<img width="220" src="../images/h2line.png" />
```

- **Must Run**

```@raw html
<img width="250" src="../images/vre.png" />
```