using MacroEnergy
using Documenter

DocMeta.setdocmeta!(MacroEnergy, :DocTestSetup, :(using MacroEnergy); recursive = true)

# Build documentation.
# ====================
makedocs(;
    modules = [MacroEnergy],
    authors = "",
    sitename = "Macro",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://macroenergy.github.io/Macro/stable/",
        # sidebar_sitename = false,
        collapselevel = 1,
    ),
    pages = [
        "Welcome to Macro" => [
            "Introduction" => "index.md"
        ],
        "Getting Started" => [
            "Overview" => "Getting Started/overview.md",
            "Installation" => "Getting Started/installation.md",
        ],
        "Tutorials" => [
            "Getting Started" => "Tutorials/tutorial_0_getting_started.md",
            "Input Files" => "Tutorials/tutorial_1_input_files.md",
            "Running Macro" => "Tutorials/tutorial_2_running_macro.md",
            "Multisector Modelling" => "Tutorials/tutorial_3_multisector_modelling.md",
        ],
        "User Guide" => [
            "Sectors" => "User Guide/sectors.md",
            "Assets" => "User Guide/assets.md",
            "Constraints" => "User Guide/constraints.md",
            "Input Data" => "User Guide/input_data.md",
            "Output" => "User Guide/output.md",
        ],
        "Modeler Guide" => [
            "How to build a sector" => "Modeler Guide/build_sectors.md",
            "How to create an example case" => "Modeler Guide/create_example_case.md",
        ],
        "Developer Guide" => [
            "Type hierarchy" => "Developer Guide/type_hierarchy.md"
        ],
        "References" => [
            "Macro Objects" => "References/macro_objects.md",
            "Asset Library" => "References/assets.md",
            "Utilities" => "References/utilities.md",
        ],
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


