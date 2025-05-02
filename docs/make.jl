using MacroEnergy
import MacroEnergy: AbstractEdge, AbstractStorage, Model
using Documenter
using DocumenterMermaid

DocMeta.setdocmeta!(MacroEnergy, :DocTestSetup, :(using MacroEnergy); recursive=true)

const pages = [
    "Welcome to Macro" => [
        "Introduction" => "index.md",
        "Table of contents" => "table_of_contents.md",
    ],
    "Guides" => [
        "Getting Started" => [
        "Overview" => "Getting Started/1_overview.md",
        "Installation" => "Getting Started/2_installation.md",
        "First Run" => "Getting Started/3_first_run.md",
        ],
        "User Guide" => [
            "Introduction" => "User Guide/user_introduction.md",
            "Create a System" => "User Guide/user_build_system.md",
            "Adding Nodes" => "User Guide/user_add_node.md",
            "Adding Locations" => "User Guide/user_add_location.md",
            "Adding Assets" => "User Guide/user_add_asset.md",
            "Adding Commodities" => "User Guide/user_add_commodity.md",
            "Adding Assets constraints" => "User Guide/user_asset_constraints.md",
            "Adding policy constraints" => "User Guide/user_policy_constraints.md",
            "Configuring settings" => "User Guide/user_settings.md",
            "Running models" => "User Guide/user_run_model.md",
            "Writing results" => "User Guide/user_write_results.md",
            "Using multi-stage models" => "User Guide/user_multistage.md",
            "Asset Library" => [
                "User Guide/assets/1_introduction.md",
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
                "User Guide/assets/vre.md"
            ],
        ],
        "Modeler Guide" => [
            "Introduction" => "Modeler Guide/1_introduction.md",
            "Creating a sector" => "Modeler Guide/modeler_build_sectors.md",
            "Creating an asset" => "Modeler Guide/modeler_build_asset.md",
            "How to create an example case" => "Modeler Guide/3_create_example_case.md",
        ],
        "Developer Guide" => [
            "Introduction" => "Developer Guide/1_introduction.md",
            "Creating a constraint" => "Developer Guide/dev_create_constraint.md",
            "Type hierarchy" => "Developer Guide/2_type_hierarchy.md",
        ],
    ],
    "Manual" => [
        "Overview" => "Manual/Overview.md",
        "Inputs" => "Manual/Inputs.md",
        "Outputs" => "Manual/Outputs.md",
        "System" => "Manual/System.md",
        "Sectors" => "User Guide/1_sectors.md",
        "Edges" => "Manual/Edges.md",
        "Nodes" => "Manual/Nodes.md",
        "Storage" => "Manual/Storage.md",
        "Transforms" => "Manual/Transforms.md",
        "Locations" => "Manual/Locations.md",
        "Assets" => "User Guide/assets/1_introduction.md",
        "Asset Library" => [
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
            "User Guide/assets/vre.md"
        ],
        "Model" => "Manual/Model.md"
    ],
    "Extended Tutorials" => [
        "Getting Started" => "Tutorials/0_getting_started.md",
        "Running Macro" => "Tutorials/1_running_macro.md",
        "Multisector Modelling" => "Tutorials/2_multisector_modelling.md",
    ],
    "How to contribute" => "how_to_contribute.md", 
    "References" => [
        "Introduction" => "References/1_introduction.md",
        "Reading input data" => "References/2_reading_input.md",
        "Macro Objects" => "References/3_macro_objects.md",
        "Writing output data" => "References/4_writing_output.md",
        "Utilities" => "References/5_utilities.md",
        # "Asset Library" => "References/2_assets.md", TODO: think if we should include this
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
    build="build_html",
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


