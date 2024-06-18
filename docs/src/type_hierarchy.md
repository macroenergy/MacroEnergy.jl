# Macro type hierarchy

```@meta
CurrentModule = Macro
```

### Commodities
```@example type_hierarchy
using Macro # hide
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
print_tree(Macro.AbstractTypeConstraint)
```


