# Creating a New Example Case

The best way to get started is by reviewing the existing example cases in the Macro repository, located in the [`ExampleSystems`](https://github.com/macroenergy/MacroEnergy.jl/tree/main/ExampleSystems) folder.

As described in [Running Macro](@ref), an example case is a directory containing all the necessary data files to run the model. The folder should follow the structure outlined below:

```
MyCase
│ 
├── 📁 settings
│   └── macro_settings.yml
│ 
├── 📁 system
│   ├── commodities.json 
│   ├── time_data.json
│   ├── nodes.json
│   ├── fuel_prices.csv
│   └── demand.csv
│ 
├── 📁 assets
│   ├── MyNewAsset1.json
│   ├── MyNewAsset2.json
| [...other asset types...]
│   └── availability.csv
│ 
└── system_data.json
```

**To test the new sector and assets**, make sure the following items are correctly set up:

```@raw html
<div style="margin-left: 2em;">
<input type="checkbox" style="margin-right: 4px;"> The new sector is included in the <strong>commodities.json</strong> file.<br>
<input type="checkbox" style="margin-right: 4px;"> The new sector is defined in the <strong>time_data.json</strong> file, with appropriate values for HoursPerTimeStep and HoursPerSubperiod.<br>
<input type="checkbox" style="margin-right: 4px;"> Nodes for the new sector are included in the <strong>nodes.json</strong> file.<br>
<input type="checkbox" style="margin-right: 4px;"> If applicable, add demand for the new sector at each relevant node in the <strong>demand.csv</strong> file.<br>
<input type="checkbox" style="margin-right: 4px;"> New assets are defined in their respective JSON files within the <strong>assets</strong> folder.<br>
<input type="checkbox" style="margin-right: 4px;"> If necessary, update the <strong>fuel_prices.csv</strong> file with the fuel prices for the new sector.<br>
<input type="checkbox" style="margin-right: 4px;"> If necessary, update the <strong>availability.csv</strong> file with the availability information for the new assets.<br>
</div>
<br>
```

!!! warning "Important Checks"
    1. Double-check that the keys in `commodities.json` and `time_data.json` exactly match the name of the new sector (i.e., the Julia abstract type name it was added to the model).
    2. Ensure that the values of the `type` keys in the node JSON entries match the name of the sector.
    3. For each asset JSON file, verify that the `type` key matches the Julia `struct` name created, and that the `commodity` keys in the `edges` and `storage` sections are correct.

