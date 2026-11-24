# Commodities

## Sub-Commodities

An edge can carry a sub-Commodity and end on a node of that sub-Commodity. These library assets read the commodity of the following edges from their input, so the edges can connect to sub-Commodity nodes:

- `VRE`: its `edge`.
- `ElectricHeating`: its `elec_edge` and `heat_edge`.
- `ThermalHeating`: its `heat_edge`.
- `HydroRes`: its `inflow_edge` and `spill_edge`. The reservoir and its `discharge_edge` stay `Electricity`.
- `CO2Injection`: its `co2_storage_edge`.
- `Electrolyzer`, `SyntheticAmmonia` and `SyntheticMethanol`: their `h2_edge`.

The commodity must belong to the family of the asset's default commodity, for example a sub-Commodity of `Hydrogen` for an `h2_edge`. Any other commodity is rejected when the edge is built. A `CO2StorageConstraint` also applies to nodes of a `CO2Captured` sub-Commodity.
