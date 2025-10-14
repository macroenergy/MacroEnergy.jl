# Timeseries

## Time Series Data in Macro

Macro supports time series data for all time-dependent inputs. Examples are demand/price for a specific commodity, availability of a renewable energy resource, etc. 

There are three main methods to provide time series data to a Macro node or asset, and the user can choose the method that is most convenient for the data they are providing:
1. Separate CSV file
2. Directly in the JSON input file for the corresponding node or asset. In this case, data can be provided in two ways:
   - Vector with a single number (constant timeseries)
   - Vector of different numbers

In the following sections, we will detail each of these methods.

## Using CSV files
The easiest way to provide time series data is to store it in a CSV file. The header/first row of the file should contain the names of each time series, and will act as labels for the time series data. The remaining rows should contain the values of the time series data.

Here is an example of a CSV file containing time series data for the demand of electricity at three zones:

`demand.csv`:

| Time\_Index | Demand\_MW\_zone1 | Demand\_MW\_zone2 | Demand\_MW\_zone3 |
| ---------- | --------------- | --------------- | --------------- |
| 1          | 50000             | 20000             | 30000             |
| 2          | 51000             | 21000             | 31000             |
| ...        | ...             | ...             | ...             |

Here is another example for availability of some renewable energy assets:

`availability.csv`:

Time\_Index | conventional\_hydroelectric\_zone1 | onshore\_wind\_turbine\_zone1 | small\_hydroelectric\_zone1 | solar\_photovoltaic\_zone1 | conventional\_hydroelectric\_zone2 | onshore\_wind\_turbine\_zone2 | small\_hydroelectric\_zone2 | solar\_photovoltaic\_zone2 | conventional\_hydroelectric\_zone3 | onshore\_wind\_turbine\_zone3 | small\_hydroelectric\_zone3 | solar\_photovoltaic\_zone3 |
| ---------- | ------------------------------- | -------------------------- | -------------------------- | ------------------------ | ------------------------------ | -------------------------- | -------------------------- | ------------------------ | ------------------------------ | -------------------------- | -------------------------- | -------------------------- |
| 1          | 0.25            | 0.65            | 0.65            | 0               | 0.60            | 0.56            | 0.60            | 0               | 0.33            | 0.0            | 0               | 0               |
| 2          | 0.25            | 0.66            | 0.25            | 0               | 0.60            | 0.57            | 0.60            | 0               | 0.33            | 0.33            | 0               | 0               |
| ...        | ...             | ...             | ...             | ...             | ...             | ...             | ...             | ...             | ...             | ...             | ...             | ...             |

Once the data is ready and stored in CSV files, the user needs to link each column to the corresponding node or asset in the JSON input file. This is done with the following steps:
1. In the `nodes.json` file or in the JSON input file for the corresponding asset, find the node or asset to which the timeseries data should be linked.
2. Find the field in the node or asset that should be linked to the timeseries data (e.g. `demand`, `price`, `availability`, etc.)
3. Add a `timeseries` dictionary with two fields:
   - `path`: the relative path to the CSV file from the case directory (e.g. `system/demand.csv`)
   - `header`: the column name in the CSV file that contains the data (e.g. `Demand_MW_zone1`)

Here are some examples of how to link the timeseries data to the corresponding node or asset in the JSON input file.

### Example: Adding electricity demand timeseries to the "electricity\_zone1" node in the system

To add electricity demand timeseries stored in the `demand.csv` CSV file under the "Demand\_MW\_zone1" column to the "electricity\_zone1" node in the system, the user would add the following to the "demand" attribute of the "electricity\_zone1" node in the `nodes.json` file:

```json
{
    "id": "electricity_zone1",
    "demand": {
        "timeseries": {
            "path": "system/demand.csv",
            "header": "Demand_MW_zone1"
        }
    },
    // [ ... other attributes ... ]
}
```

This will link the timeseries data stored in the `demand.csv` under the "Demand\_MW\_zone1" column to the demand attribute of the "electricity\_zone1" node.

### Example: Adding natural gas price timeseries to the "natgas\_fossil\_zone1" node in the system

Similarly, to add natural gas price timeseries stored in the `fuel_prices.csv` CSV file under the "natgas\_fossil\_zone1" column to the "natgas\_fossil\_zone1" node in the system, the user would add the following to the "price" attribute of the "natgas\_fossil\_zone1" node in the `nodes.json` file:  

```json
{
    "id": "natgas_fossil_zone1",
    "price": {
        "timeseries": {
            "path": "system/fuel_prices.csv",
            "header": "natgas_fossil_zone1"
        }
    },
    // [ ... other attributes ... ]
}
```

This will link the timeseries data stored in the `fuel_prices.csv` under the "natgas\_fossil\_zone1" column to the price attribute of the "natgas\_fossil\_zone1" node.

### Example: Adding availability timeseries to the "existing\_solar\_zone1" asset in the system

To add availability timeseries stored in the `availability.csv` CSV file under the "solar\_photovoltaic\_zone1" column to the "existing\_solar\_zone1" asset in the system, the user would add the following to the "availability" attribute of the "existing\_solar\_zone1" asset in the `assets.json` file:


```json
{
    "id": "existing_solar_zone1",
    "availability": {
        "timeseries": {
            "path": "system/availability.csv",
            "header": "solar_photovoltaic_zone1"
        }
    },
    "location": "zone1",
    // [ ... other attributes ... ]
}
```

!!! warning "Important notes"
    - The number of data rows in the CSV must match the total number of reference timesteps in your model as specified in the `time_data.json` file (e.g., 8760 for an hourly annual model)
    - The first column in the CSV (e.g., `Time_Index` or `TimeStep`) is optional and used only for reference

## Using a scalar value

To reduce memory usage, when a parameter is constant across all timesteps, users can provide it as a vector with a single value directly in the JSON input file.

### Example: Constant price timeseries for the "natgas\_fossil\_zone1" node in the system

```json
{
    "id": "natgas_fossil_zone1",
    "price": [15.0],
    // [ ... other attributes ... ]
}
```

This is equivalent to having the same value repeated for all timesteps, but more compact. Macro will automatically broadcast this value to all timesteps when the model is generated.

**Note:** The value must still be provided as a vector (with square brackets `[]`), even though it contains only one element.

## Using a vector of numbers

For shorter timeseries or when CSV files are inconvenient, users can directly specify the timeseries as a vector of numbers in the JSON file.

### Example: Vector timeseries in the JSON input file for the "electricity_zone1" node in the system

```json
{
    "id": "electricity_zone1",
    "demand": [100, 110, 120, 105, 95, 100, 115, 125],
    // [ ... other attributes ... ]
}
```

This is useful when:
- Users have a small number of timesteps
- The timeseries values are generated programmatically
- Users want to keep all data in a single file

## Summary

| Method | Use Case | Example |
|--------|----------|---------|
| CSV with `timeseries` dict | Large datasets, multiple timeseries, shared across runs | `"demand": {"timeseries": {"path": "system/demand.csv", "header": "Zone1"}}` |
| Single-value vector in JSON | Constant parameters | `"price": [15.0]` |
| Vector in JSON | Short timeseries, programmatically generated data | `"demand": [100, 110, 120, ...]` |
