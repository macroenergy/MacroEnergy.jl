using MacroEnergy
using Documenter

DocMeta.setdocmeta!(MacroEnergy, :DocTestSetup, :(using MacroEnergy); recursive = true)

# Build documentation.
# ====================
makedocs(;
    modules = [MacroEnergy],
    authors = "",
    sitename = "Macro",
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", "false") == "true"),
    pages = [
        "Home" => "index.md",
        "Installation" => "installation.md",
        "Macro Components" => [
            "Sectors" => "sectors.md",
            "Assets" => "assets.md",
            "Constraints" => "constraints.md"
        ],
        "Output" => "output.md",
        "Modeling with Macro" => [
            "How to build a sector" => "build_sectors.md",
            "How to create an example case" => "create_example_case.md",
        ],
        "Developer docs" => [
            "Type hierarchy" => "type_hierarchy.md",
            "Data model" => "data_model.md",
        ],
        "References" => "references.md",
    ],
)

# Deploy built documentation.
# ===========================
deploydocs(;
    repo="https://github.com/macroenergy/MacroEnergy.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "develop",
    devurl = "dev",
    push_preview=true,
)


