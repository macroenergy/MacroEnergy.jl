# Grouped Capacity Constraints

Grouped capacity constraints bound installed or newly built capacity across a selected group of
assets. They are configured in input data, rather than in model settings, and can apply either to
the entire system or to an individual location.

Macro provides three grouped constraints:

| Constraint | Aggregated quantity | Bound |
|:--|:--|:--|
| `MaxCapacityConstraint` | total installed `capacity` | $\sum \mathrm{capacity} \leq \mathrm{value}$ |
| `MinCapacityConstraint` | total installed `capacity` | $\sum \mathrm{capacity} \geq \mathrm{value}$ |
| `MaxNewCapacityConstraint` | total `new_capacity` | $\sum \mathrm{new\_capacity} \leq \mathrm{value}$ |

## Configuration shape

Each grouped constraint uses an object payload in a `constraints` block. Each named group specifies
an asset selector, the asset edge field to aggregate, and its limit.

```json
"<ConstraintName>": {
  "<group-name>": {
    "select": {
      "asset_type": "<asset-type>",
      "all": ["<required-tag>"],
      "any": ["<alternative-tag>"],
      "exclude": ["<excluded-tag>"]
    },
    "edge": "<asset struct field>",
    "value": 1000.0
  }
}
```

`edge` is a field name on every selected asset, such as `"edge"` for `VRE` or `"elec_edge"` for
`ThermalPower`. The selected edge must have a capacity variable. `asset_type`, `all`, `any`, and
`exclude` are individually optional, but a selector must provide at least one of them.

The object is parsed into the constraint's typed configuration object:
[`MaxCapacityConstraintConfig`](@ref), [`MinCapacityConstraintConfig`](@ref), or
[`MaxNewCapacityConstraintConfig`](@ref). The supported group keys are exactly `edge` and `value`.

!!! warning "A Boolean is not enough at system or location scope"

    Grouped constraints at system and location scope require an object payload. For example,
    `"MaxCapacityConstraint": true` is invalid because it provides no group or limit. Macro reports
    that a `MaxCapacityConstraintConfig` object is required and asks for an object payload instead.

## System-wide limits

Put system-wide grouped constraints in the top-level `constraints` block of `system_data.json`.

```json
{
  "constraints": {
    "MinCapacityConstraint": {
      "renewable_vre": {
        "select": { "asset_type": "VRE", "all": ["renewable"] },
        "edge": "edge",
        "value": 200.0
      }
    },
    "MaxCapacityConstraint": {
      "renewable_vre": {
        "select": { "asset_type": "VRE", "all": ["renewable"] },
        "edge": "edge",
        "value": 1000.0
      }
    },
    "MaxNewCapacityConstraint": {
      "renewable_vre": {
        "select": { "asset_type": "VRE", "all": ["renewable"] },
        "edge": "edge",
        "value": 800.0
      }
    }
  }
}
```

This requires at least 200 units of total VRE capacity, caps total VRE capacity at 1000, and caps
new VRE construction at 800 across the entire system. The three constraints are independent and
may be combined in one block.

## Per-location limits

Location entries may be objects with their own `constraints` block; bare location IDs remain valid.
Place the same payload below the location that should enforce it.

```json
{
  "locations": [
    {
      "id": "SE",
      "constraints": {
        "MaxCapacityConstraint": {
          "vre": {
            "select": { "asset_type": "VRE" },
            "edge": "edge",
            "value": 300.0
          }
        }
      }
    },
    {
      "id": "MIDAT",
      "constraints": {
        "MaxCapacityConstraint": {
          "vre": {
            "select": { "asset_type": "VRE" },
            "edge": "edge",
            "value": 500.0
          }
        }
      }
    },
    "NE"
  ]
}
```

System-wide and per-location limits can both be active. For example, total VRE capacity can be at
most 1000 while VRE capacity in `SE` is independently limited to 300.

For a per-location group, Macro finds an edge's location in this order: the edge's own `location`,
its end vertex's location, then its start vertex's location. Assets outside the configured location
do not contribute to that group's expression.

## Selecting assets

`asset_type` uses the Julia asset type hierarchy, so `"VRE"` selects every VRE variant and
`"ThermalPower"` selects every commodity variant of thermal power. Tags refine or replace that
structural selection. All selectors use the following logic:

```text
asset_type matches (when supplied)
AND every `all` tag is present
AND at least one `any` tag is present (when supplied)
AND no `exclude` tag is present
```

For example, this selects active utility-scale or distributed solar VRE:

```json
"select": {
  "asset_type": "VRE",
  "all": ["solar"],
  "any": ["utility_scale", "distributed"],
  "exclude": ["retired"]
}
```

Assets define `tags` in `global_data` and/or `instance_data`. Global and instance tags are combined;
an instance can add tags but cannot remove a global tag. Tags are validated, normalized to lowercase
snake-case symbols, and stored on the constructed asset. For example, `"Utility Scale"` and
`"utility-scale"` both become `:utility_scale`.

The prototype key form `"VRE{Solar}"` remains valid as a compatibility input. It is parsed as
`asset_type = "VRE"` with `all = ["solar"]`; it does not invoke parametric-type matching. VRE
assets automatically receive their normalized `technology` value as a tag, so existing
`"technology": "Solar"` input works with that compatibility form.

A group that matches no assets produces a warning and no constraint for that group. A group that has
no matching assets in a configured location is skipped. If a selected asset lacks the specified edge
field, Macro reports an error; if the field has no capacity variable, that asset is skipped with a
warning.

## Parameter scaling

Group `value`s are capacity quantities. When `ParameterScaling` is enabled, Macro divides them by
`ParameterScalingFactor` before solving and restores their original values after the solve. This
keeps grouped limits consistent with the scaled capacity and new-capacity variables.
