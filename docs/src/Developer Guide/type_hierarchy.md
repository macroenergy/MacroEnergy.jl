# Developer Guide

## Macro type hierarchy

```@meta
CurrentModule = MacroEnergy
```

### Commodities
```@example type_hierarchy
using MacroEnergy # hide
using AbstractTrees # hide
using InteractiveUtils # hide
AbstractTrees.children(d::DataType) = subtypes(d) # hide
print_tree(Commodity)
```

### Assets
```@example type_hierarchy
print_tree(AbstractAsset)
```

### Constraints
```@example type_hierarchy
print_tree(MacroEnergy.AbstractTypeConstraint)
```


