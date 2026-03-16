# General assumptions made by Macro

**Planning periods** (also referred to as "periods") can include multiple years. The number of years can vary between planning periods. (This has implications for how to aggregate variable and O&M costs within a period, see below.)

**Timing of capacity deployment**: New capacity comes online instantaneously at the beginning of a period. 

**Representativeness of modeled year**: Each period is modeled using one year; i.e., the modeled energy production occurs over the course of a single year. In cases where a period covers multiple years, period-wide costs are based on a scaling of the modeled annual costs. The current assumption in Macro is that the year modeled is representative. Thus, variable costs over a period represent annual costs multiplied by the number of years (subject to discounting, see below). This assumption can have important implications for the accuracy of the period-wide costs if conditions within the system are expected to be changing within a given period. For example, if demand grows over the period and the demand inputted by the user represents the final year of the modeled period, the current approach can overestimate variable costs incurred in the beginning of the period. The recommended practice would be to define periods such that conditions within a period do not change meaningfully between the years of the period. 

**Age-based retirement**: A unit of capacity reaching end-of-life within period $i$ will retire at the beginning of period $i+1$, and so will be available for the entirety of period $i$.  If the user intends to capture retirements within a period, the recommended approach would be to define different periods for this purpose.

**Economic retirement**: A unit of capacity that is retired for economic reasons in a given period $i$ is assumed to be retired as of the beginning of the first year of period $i$. This means that retired capacity incurs no O&M costs in that period.

**Timing of cost incidence**: All annual costs (investment, variable, and O&M costs) are assumed to be incurred at the end of the respective year. (This has implications for how costs are discounted.)

**Time value of money**: The objective function is expressed in *present value* terms from the standpoint of the beginning of the modeling horizon; i.e., all costs are discounted to that point (see discounting below). 

**Inflation**: The objective function is expressed in *real dollars*. The choice of dollar year is up to the user, but all cost inputs should be expressed in the same dollar-year terms. 

# Discounting

## Perfect foresight

### Investment cost

The total investment cost in the objective function is expressed as:
```math
\text{Investment cost} = \sum_y \sum_z \sum_i \sum_{j=1}^{P_i} \frac{1}{(1+DR)^{j+N_i}} \text{Annualized investment cost}_{y,z,i}
```

where: 
- $\text{Annualized investment cost}_{y,z,i}$ represents the product of annualized cost per unit of capacity and the amount of capacity deployed.
- $y$ indexes technologies, $z$ indexes zones, and $i$ indexes periods.
- DR represents the general discount rate (which can equivalently be referred to as the social discount rate)
- $N_i$ is the number of years from the beginning of the modeling horizon to the first year of period $i$.

```math
N_i = \sum_{i=1}^{i-1}L_i
```

- $L_i$ is the number of years in period $i$
- $P_i$ is the minimum of the economic lifetime or the total number of years across all remaining periods.

```math
P_i=\min(EL_y, \sum_{s=i}^{|I|}L_s)
```

## Fixed O&M cost

```math
\text{Fixed O\&M cost} = \sum_i^{|I|} \sum_{j=1}^{L_i} \frac{1}{(1+DR)^{j+N_i}} \text{Annual Fixed O\&M cost}_i
```

## Variable cost

 Annual costs must be summed over periods $i$, based on the number of years within each period $L_i$, and discounted:

```math
\text{Variable cost} = \sum_i^{|I|} \sum_{j=1}^{L_i} \frac{1}{(1+DR)^{j+N_i}} \text{Annual variable cost}_i
```

## Myopic

### Investment cost

```math
\text{Investment cost}_i = \sum_y^{|G|} \sum_z^{|Z|} \sum_{j=1}^{P_i} \frac{1}{(1+DR)^{j+N_i}} \text{Annualized investment cost}
```

where:

$P_i$ is the minimum of the economic lifetime or the total number of years in the period (a period will typically be shorter in duration than the economic lifetime). 

```math
P_i = \min(EL_y, L_i)
```

Note that the costs reported out of the model add back annuities not considered by the myopic foresight, to enable comparisons with the perfect foresight case. In other words, the reported investment cost is calculated using $P_i = \min(EL_y, \sum_{i}^{|I|}L_i)$.

### Fixed O&M costs

```math
\text{Fixed O\&M cost}_i = \sum_{j=1}^{L_i} \frac{1}{(1+DR)^{j+N_i}} \text{Annual Fixed O\&M cost}_i
```

### Variable cost

```math
\text{Variable cost}_i = \sum_{j=1}^{L_i} \frac{1}{(1+DR)^{j+N_i}} \text{Annual variable cost}_i
```


# Cost outputs

Reported in two forms:
*  **Discounted** costs are reported in "costs.csv". These expressed in present value terms from the perspective of the beginning of the modeling horizon (this corresponds to the values considered in the objective function)
*  **Undiscounted**: expressed in present value terms from the perspective of the point in time when the costs incurred.

All reported cost components for a given period represent costs for the whole period; i..e, costs are not in annual terms. Users can multiply these outputs by the appropriate coefficients (based no number of years in each period) to estimate annual costs from the reported data.




