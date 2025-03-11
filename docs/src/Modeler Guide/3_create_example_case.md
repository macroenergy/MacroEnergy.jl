# How to create an example case to test the new sectors and assets

Once new sectors and assets have been created in the model, you may want to test them by creating a new example case. This section explains how to achieve this.

The best way to create a new example case is to include the new sectors and assets in an existing example case. They can be found in the `ExampleSystems` folder in the `Macro` repository.

An example case is a folder that contains all the necessary data files to run the model. The case folder should have the following structure:

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
│   ├── MyAsset1.json
│   ├── MyAsset2.json
| [...other asset types...]
│   └── availability.csv
│ 
└── system_data.json
```

When adding a new sector, you need to make sure that: 
- The new sector is included in the `commodities.json` file.
- The new sector is included in the `time_data.json` file, with the corresponding `HoursPerTimeStep` and `HoursPerSubperiod` values.
- Nodes corresponding to the new sector are included in the `nodes.json` file.
- The demand corresponding to the new sector and for each node is included in the `demand.csv` file.
- A new JSON file is created with the data for the new assets.
- `Availability.csv` and `fuel_prices.csv` files are updated with the availability and fuel prices for the new assets (if applicable).

!!! warning "Warning"
    Make sure that the values of the `type` keys in the JSON files match the names of the new sector and assets (julia `abstract type` and `struct` names respectively) created in the model.
    The same applies to the `keys` in the `commodities.json` and `time_data.json` files.