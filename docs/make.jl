using Macro
using Documenter

DocMeta.setdocmeta!(Macro, :DocTestSetup, :(using Macro); recursive = true)

# Build documentation.
# ====================
makedocs(;
    modules = [Macro],
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
    repo="https://github.com/macroenergy/Macro",
    target = "build",
    branch = "gh-pages",
    devbranch = "develop",
    devurl = "dev",
    push_preview=true,
)


