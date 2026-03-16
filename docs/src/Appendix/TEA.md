# [Techno-Economic Analysis Simplified: A Practical Guide for Macro Users](@id tea)

## [Authors](@id tea_authors)

Hongxi Luo and Eric D. Larson

Andlinger Center for Energy and the Environment, Princeton University,
Princeton, NJ 08540, USA

## [Background](@id tea_background)

This document provides high-level guidance and practical
recommendations for Macro users who are new to techno-economic analysis,
assisting them in extracting relevant techno-economic parameters from
the literature for technology assets to be represented in Macro. While
not required by Macro, it is strongly recommended that users carefully
document the sources of the techno-economic parameters for all assets.

## [Example System](@id tea_example_system)

The Natural Gas Combined Cycle with carbon capture
and storage (NGCC-CCS), categorized under "ThermalPowerCCS" in Macro, is
used as the example, with the technical report "Cost and Performance
Baseline for Fossil Energy Plants Volume 1: Bituminous Coal and Natural
Gas to Electricity" from the National Energy Technology Laboratory
(NETL) \[1\] serving as the primary reference. Tables and figures in
this NETL report are labeled "Exhibits 1-1", "Exhibit 2-1", etc. and so
will be referred to in this guide as "Ex 1-1", "Ex 2-1", etc.

## [System Description](@id tea_system_description)

The example has two significant components ---
the NGCC power plant and the CCS facility.

- The NGCC power plant features a 2×2×1 configuration, consisting of two
  F-class combustion turbine generators (CTGs), two heat recovery steam
  generators (HRSGs), and one steam turbine generator (STG).

- The CCS facility captures 90% of the CO₂ from the flue gas exiting
  the HRSGs using the Cansolv (amine solvent) system, purifies it, and
  compresses it to conditions suitable for pipeline transportation.

## [Fuel Properties](@id tea_fuel_properties)

Parameters related to fuel properties are
"*emission_rate*" and "*capture_rate*".

- Ex 2-6 provides the natural gas composition on a volumetric basis.
  Under standard conditions and assuming ideal gas behavior, the
  volumetric composition can be approximated by the molar composition.
  By applying the appropriate molecular weight (e.g., 16 kg/kmol for
  CH₄) and accounting for the atom balance (e.g., one carbon atom per
  CH₄ molecule), the CO₂ emissions embedded in natural gas (assuming
  eventual complete combustion) are 2.64 kg CO₂ per kg of natural gas,
  or 2.64 tonnes of CO₂ per tonne of natural gas.

- Ex 2-6 provides the higher heating value (HHV) and lower heating value
  (LHV) of natural gas: 52,295 kJ/kg and 47,201 kJ/kg, respectively.
  Dividing these numbers by 3,600 to convert kJ/kg into MWh/tonne, the
  HHV and LHV of natural gas are 14.53 MWh/tonne and 13.11 MWh/tonne,
  respectively.

- Based on the calculations above, the CO₂ emissions embedded in natural
  gas are 0.182 tonnes of CO₂ per MWh of natural gas (HHV basis) and
  0.201 tonnes of CO₂ per MWh of natural gas (LHV basis). Upon complete
  combustion, all the CO₂ embedded in natural gas is converted to CO₂ in
  the flue gas, with 90% captured and 10% emitted.

- The *emission_rate* for this asset in the Macro is 0.0182 tonnes of
  CO₂ per MWh of natural gas (HHV basis) or 0.0201 tonnes of CO₂ per MWh
  (LHV basis).

- The *capture_rate* for this asset in the Macro is 0.1638 tonnes of CO₂
  per MWh of natural gas (HHV basis) and 0.1809 tonnes of CO₂ per MWh
  (LHV basis).

### [Fuel Properties - Notes](@id tea_fuel_properties_notes)

- The calculation method above relies on fuel composition and elemental
  balance, ensuring high analytical rigor. In cases where this
  information is unavailable, users can refer to well-established
  emission factors for fuels.

- The calculations above reflect the emissions associated with natural
  gas consumption. However, emissions from natural gas extraction and
  transportation can also be significant and should be incorporated
  separately in other sections of the Macro model. These considerations
  apply equally to other fuels, including coal and biomass.

- Users should recognize that CO₂ removal efficiency (e.g., 90% for
  the NGCC-CCS case) is specific to each technology asset and must
  ensure that an appropriate CO₂ removal efficiency is used when
  calculating both the *emission_rate* and the *capture_rate*.

## [Steady-state Operation](@id tea_steady_state_operation)

Key parameters for steady-state operations
are "*fuel_consumption*" and "*capacity_size*".

- Ex 5-23 shows that the NGCC-CCS facility has a net electric power
  output of 646 MWe. Hence, the *capacity_size* for this asset in the
  Macro is 646 MWe.

- Ex 5-23 indicates that the net plant efficiency is 47.7% (HHV basis)
  and 52.8% (LHV basis). Therefore, the *fuel_consumption* (reciprocal
  of efficiency) for this asset in the Macro is 2.096 (HHV basis) or
  1.894 (LHV basis).

### [Steady-state Operation - Notes](@id tea_steady_state_operation_notes)

- Within an asset, users must ensure that they input the
  *emission_rate*, *capture_rate*, and *fuel_consumption* using a
  consistent heating value basis, either LHV or HHV.

- It is recommended that users use the *capacity_size* and
  *fuel_consumption* that are representative of the geographic region of
  interest. For technology assets expected to be deployed only in the
  future, it may be acceptable to use *capacity_size* and
  *fuel_consumption* projections from other regions if no specific
  values are available for the region of interest.

## [Project Economics](@id tea_project_economics)

Parameters related to project economics are
"*investment_cost*", "*fixed\_om\_cost*", "*variable\_om\_cost*" and fuel
cost.

- Ex 5-32 shows that the total as-spent cost (TASC) of the NGCC-CCS
  facility is \$1,701,831,000 (in 2018 dollars). Dividing this by the
  facility's capacity (i.e., *capacity_size*) of 646 MWe yields a unit
  capacity investment of \$2,634,413 per MWe (in 2018 dollars).
  Therefore, in the Macro model, the *investment\_cost* for this asset is
  \$2,634,413/MWe. If users instead wish to input an
  *annualized\_investment\_cost*, a capital recovery factor (e.g., 0.07 as
  recommended in another NETL report \[2\]) can be applied to the
  *investment\_cost*, resulting in an *annualized\_investment\_cost* of
  \$184,409/yr-MWe (in 2018 dollars) for this asset in the Macro model.

- Ex 5-33 indicates that the annual fixed operating costs are \$63.91
  per year per kWe (in 2018 dollars). Therefore, the *fixed\_om\_cost* for
  this asset in the Macro model is \$63,911/yr-MWe (in 2018 dollars).

- Ex 5-33 shows that the variable operating costs (which excludes fuel
  costs) are \$5.63 per MWh (in 2018 dollars). Hence, the
  *variable\_om\_cost* for this asset in the Macro model is \$5.63/MWh (in
  2018 dollars).

- The study uses a natural gas price of \$4.19 per GJ on an HHV basis
  (in 2018 dollars, as noted in the paragraph above Exhibit 2-6). As a
  result, users should input \$15.08/MWh for all cells under
  "Time\_Index" in the "fuel\_price.csv" file.

### [Project Economics - Notes](@id tea_project_economics_notes)

- Ideally, techno-economic parameters reported by studies that
  thoroughly discuss input data and assumptions should be prioritized. A
  good example of such studies, in the form of a journal article, is
  \[3\].

- Users should carefully identify the underlying assumptions and
  considerations for capital cost estimates, such as which cost layers
  are included, how each cost layer is evaluated, and whether the
  project is first-of-its-kind or commercially mature, because these
  factors can significantly influence the final capital cost value. For
  example, in Ex 2-20 of the NETL report, the capital cost is divided
  into five layers, ranging from the bare-erected cost (BEC) to the
  total as-spent cost (TASC). In the case of the NGCC-CCS facility, the
  BEC, as shown in Ex 5-31, is \$847,376,000 (in 2018 dollars). If this
  value is used instead of the TASC, the *investment\_cost* for this
  asset in the Macro model would be \$1,311,727/MWe (in 2018 dollars).
  In this case, understanding whether to use TASC or one of the other
  capital cost layers in the NETL report is the responsibility of the
  user.

- Users should carefully identify the base year of the capital cost
  values (e.g., 2018 for the NGCC-CCS example) and ensure consistency in
  the base year used across different assets. If the base year differs
  between the collected values, appropriate indexes, such as the
  Chemical Engineering Plant Cost Index (CEPCI) \[4\] or its equivalent,
  should be referenced and applied to adjust all base years to a common
  desired base year.

- Users should carefully identify the geographic region for which
  capital cost values are developed and always use values specific to
  the region of interest. If capital costs for the desired region are
  unavailable, location factors may be used to adjust values from
  another region \[5\]. Generally, it is inappropriate to apply capital
  cost values directly from one region to another.

- Users should understand that once a capital cost value --- whether
  derived from real-world projects or engineering design studies --- is
  selected as a representative value for an asset in the Macro model, it
  becomes a user estimate. This estimate is unlikely to be more accurate
  than a Class IV estimate, as defined by the Association for the
  Advancement of Cost Engineering (AACE) \[6\], which has an uncertainty
  range of -30% to +50%. This range should be kept in mind when
  considering conducting sensitivity analysis on *investment_cost*
  values.

- Users should recognize that the reported capital cost value typically
  corresponds to the capacity of a specific facility. If this capacity
  differs from the one of interest, e.g., if the available capital cost
  estimate is for a 300 MW NGCC plant, while most NGCC plants in the
  region of interest are 500 MW, a scaling method can be applied.
  Further details on how to properly conduct the scaling process can be
  found in a NETL report \[7\].

- It is recommended that users obtain region- and technology-specific
  weighted-average cost of capital (WACC) \[8\], which forms a key part
  of the capital recovery factor (CRF) used to convert *investment\_cost*
  into *annualized\_investment\_cost*. At a minimum, a region-specific,
  technology-agnostic WACC should be used.

- The annual fixed operating costs (*fixed\_om\_cost*) typically include
  labor costs, maintenance costs, and property taxes and insurance.
  Apart from labor costs, the other expenses are generally estimated as
  a small percentage of the capital cost. Consequently, the base year of
  these costs should be adjusted in the same manner as capital costs,
  i.e., using the CEPCI or an equivalent index. For labor costs,
  statistics published by the Bureau of Labor (or equivalent
  organization in a region) could be consulted to determine an
  appropriate salary for asset operators in the desired base year.

- Users should ensure that the annual variable operating costs
  (*variable\_om\_cost*) do not include fuel costs, as some studies
  combine them. Since the price of consumables can vary significantly,
  using a most recent 10-year average adjusted for inflation to reflect
  the desired base year is considered a reasonable approach.

## [References](@id tea_references)

1\. James Iii, R.E., et al., *Cost and performance baseline for fossil
energy plants volume 1: bituminous coal and natural gas to electricity*.
2019, National Energy Technology Laboratory (NETL), Pittsburgh, PA,
Morgantown, WV .... Available from:
[https://www.osti.gov/biblio/1569246](https://www.osti.gov/biblio/1569246)

2\. Theis, J., *Quality Guidelines for Energy Systems Studies: Cost
Estimation Methodology for NETL Assessments of Power Plant Performance*.
2021: United States.

3\. Luo, H., et al., *Biopower with molten carbonate fuel cell carbon
dioxide capture: Performance, cost, and grid-integration evaluations.*
Energy Conversion and Management, 2024. **322**: p. 119167.

4\. The Chemical Engineering Plant Cost Index. Chemical Engineering,
2023 \[cited 2023 Feb 28\]; Available from:
<https://www.chemengonline.com/pci-home>.

5\. Towler, G. and R. Sinnott, *Chemical engineering design: principles,
practice and economics of plant and process design*. 2021:
Butterworth-Heinemann.

6\. Christensen, P., et al., *Cost Estimate Classification system-as
applied in engineering, procurement, and construction for the process
industries.* AACE International Recommended Practices, 2005: p. 1-30.

7\. Zoelle, A. and N. Kuehn, *Quality Guidelines for Energy System
Studies: Capital Cost Scaling Methodology: Revision 4 Report*. 2019,
National Energy Technology Laboratory (NETL), Pittsburgh, PA,
Morgantown, WV ....

8\. Davis, D. *Methods, Assumptions, Scenarios & Sensitivities*. Net
Zero Australia 2023 \[cited 2025 Jan, 2nd\]; Available from:
<https://www.netzeroaustralia.net.au/wp-content/uploads/2023/04/Net-Zero-Australia-Methods-Assumptions-Scenarios-Sensitivities.pdf>.
