using MacroEnergy
import MacroEnergy: AbstractEdge, AbstractStorage, Model
using Documenter

DocMeta.setdocmeta!(MacroEnergy, :DocTestSetup, :(using MacroEnergy); recursive=true)

const pages = [
    "Welcome to Macro" => [
        "Introduction" => "index.md",
        "Table of contents" => "table_of_contents.md",
    ],
    "Getting Started" => [
        "Overview" => "Getting Started/overview.md",
        "Installation" => "Getting Started/installation.md",
        "First Run" => "Getting Started/first_run.md",
    ],
    "Tutorials" => [
        "Getting Started" => "Tutorials/0_getting_started.md",
        # "Input Files" => "Tutorials/tutorial_1_input_files.md",
        "Running Macro" => "Tutorials/1_running_macro.md",
        "Multisector Modelling" => "Tutorials/2_multisector_modelling.md",
    ],
    "User Guide" => [
        "Sectors" => "User Guide/sectors.md",
        "Input Data" => "User Guide/input_data.md",
        "Assets" => ["User Guide/assets/introduction.md",
            "User Guide/assets/battery.md",
            "User Guide/assets/beccselectricity.md",
            "User Guide/assets/beccshydrogen.md",
            "User Guide/assets/electricdac.md",
            "User Guide/assets/electrolyzer.md",
            "User Guide/assets/fuelcell.md",
            "User Guide/assets/gasstorage.md",
            "User Guide/assets/hydrogenline.md",
            "User Guide/assets/hydropower.md",
            "User Guide/assets/mustrun.md",
            "User Guide/assets/natgasdaq.md",
            "User Guide/assets/powerline.md",
            "User Guide/assets/thermalhydrogen.md",
            "User Guide/assets/thermalpower.md",
            "User Guide/assets/vre.md"],
        "Constraints" => "User Guide/constraints.md",
        "Output" => "User Guide/output.md",
    ],
    "Modeler Guide" => [
        "Overview" => "Modeler Guide/overview.md",
        "How to build a sector" => "Modeler Guide/build_sectors.md",
        "How to create an example case" => "Modeler Guide/create_example_case.md",
    ],
    "Developer Guide" => [
        "Overview" => "Developer Guide/overview.md",
        "Type hierarchy" => "Developer Guide/type_hierarchy.md"
    ],
    "References" => [
        "Macro Objects" => "References/macro_objects.md",
        "Asset Library" => "References/assets.md",
        "Utilities" => "References/utilities.md",
    ],
]

# Build documentation.
# ====================
# HTML documentation
makedocs(;
    modules=[MacroEnergy],
    authors="",
    sitename="Macro",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://macroenergy.github.io/Macro/stable/",
        # sidebar_sitename = false,
        collapselevel=1,
    ),
    build = "build_html",
    pages=pages,
)

# # PDF documentation
# Documenter.makedocs(
#     modules = [MacroEnergy],
#     authors = "Macro Energy Team",
#     sitename = "Macro",
#     format = Documenter.LaTeX(),
#     build = "build_pdf",
#     pages = pages,
# )

# Deploy built documentation.
# ===========================
deploydocs(;
    repo="https://github.com/macroenergy/MacroEnergy.jl.git",
    target="build",
    branch="gh-pages",
    devbranch="develop",
    devurl="dev",
    push_preview=true,
)


