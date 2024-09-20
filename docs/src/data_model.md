# Structure of the data model of Macro

```
MyCase
│ 
├── 📁 settings
│   ├── macro_settings.yml      
│   ├── solver_settings.yml     
│   └── cpuconfig.yml           # Hardware configuration
│ 
├── 📁 system
│   ├── commodities.json 
│   ├── time_data.json
│   ├── nodes.json
│   └── demand.csv
│ 
├── 📁 assets
│   ├──battery.json
│   ├──electrolyzers.json
│   ├──fuel_prices.csv
│   ├──fuelcell.json
│   ├──h2storage.json
│   ├──power_lines.json
│   ├──thermal_h2.json
│   ├──thermal_power.json
│   ├──vre.json
| [...other asset types...]
│   ├──availability.csv
│   └── fuel_prices.csv
│ 
└── system_data.json
```

