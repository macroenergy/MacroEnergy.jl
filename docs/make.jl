using MacroEnergy
using HiGHS
import MacroEnergy: AbstractEdge, AbstractStorage, Model
using Documenter
using DocumenterMermaid

DocMeta.setdocmeta!(MacroEnergy, :DocTestSetup, :(using MacroEnergy); recursive=true)

const pages = [
    "Welcome to Macro" => [
        "Introduction" => "index.md",
        "Table of contents" => "table_of_contents.md",
    ],
    "Getting Started" => [
        "Overview" => "Getting Started/1_overview.md",
        "Installation" => "Getting Started/2_installation.md",
        "What's Included With Macro" => "Getting Started/4_macro_repo_contents.md",
        "First Run" => "Getting Started/3_first_run.md",
    ],
    "Tutorials" => [
        "Introduction" => "Tutorials/tutorials_introduction.md",
        "Getting Started" => "Tutorials/0_getting_started.md",
        "Running Macro" => "Tutorials/1_running_macro.md",
        "Multisector Modelling" => "Tutorials/2_multisector_modelling.md",
    ],
    "Guides" => [
        "Introduction" => "Guides/guides_introduction.md",
        "User Guide" => [
            "Create a System" => "Guides/User Guide/user_build_system.md",
            "Adding Commodities" => "Guides/User Guide/user_add_commodity.md",
            "Adding Nodes" => "Guides/User Guide/user_add_node.md",
            "Adding Locations" => "Guides/User Guide/user_add_location.md",
            "Adding Assets" => "Guides/User Guide/user_add_asset.md",
            "Adding Policy constraints" => "Guides/User Guide/user_policy_constraints.md",
            "Adding Assets constraints" => "Guides/User Guide/user_asset_constraints.md",
            "Configuring Settings" => "Guides/User Guide/user_settings.md",
            "Running Models" => "Guides/User Guide/user_run_model.md",
            "Writing Results" => "Guides/User Guide/user_write_results.md",
            "Using Multi-Stage Models" => "Guides/User Guide/user_multistage.md",
            "Exploring the Asset library" => "Guides/User Guide/user_using_asset_libary.md"
        ],
        "Modeler Guide" => [
            "Introduction" => "Guides/Modeler Guide/modeler_introduction.md",
            "Energy System Graph-Based Representation" => "Guides/Modeler Guide/modeler_es_graph.md",
            "Creating a New Sector" => "Guides/Modeler Guide/modeler_build_sectors.md",
            "Creating a New Asset" => "Guides/Modeler Guide/modeler_build_asset.md",
            "Creating a New Example Case" => "Guides/Modeler Guide/modeler_create_example_case.md",
            "Suggested Development Workflow" => "Guides/Modeler Guide/modeler_workflow.md",
            "Debugging and Testing" => "Guides/Modeler Guide/modeler_debugging_testing.md",
        ],
        "Developer Guide" => [
            "Creating a Constraint" => "Guides/Developer Guide/dev_create_constraint.md",
            "Type Hierarchy" => "Guides/Developer Guide/2_type_hierarchy.md",
        ],
    ],
    "Manual" => [
        "Introduction" => "Manual/manual_introduction.md",
        "Inputs" => "Manual/Inputs.md",
        "Outputs" => "Manual/Outputs.md",
        "System" => "Manual/System.md",
        "Sectors" => "Manual/Sectors.md",
        "Edges" => "Manual/Edges.md",
        "Nodes" => "Manual/Nodes.md",
        "Storage" => "Manual/Storage.md",
        "Transforms" => "Manual/Transforms.md",
        "Locations" => "Manual/Locations.md",
        "Assets" => "Manual/assets/1_introduction.md",
        "Asset Library" => [
            "Manual/assets/battery.md",
            "Manual/assets/beccselectricity.md",
            "Manual/assets/beccshydrogen.md",
            "Manual/assets/electricdac.md",
            "Manual/assets/electrolyzer.md",
            "Manual/assets/fuelcell.md",
            "Manual/assets/gasstorage.md",
            "Manual/assets/hydrogenline.md",
            "Manual/assets/hydropower.md",
            "Manual/assets/mustrun.md",
            "Manual/assets/natgasdaq.md",
            "Manual/assets/transmissionlink.md",
            "Manual/assets/thermalhydrogen.md",
            "Manual/assets/thermalpower.md",
            "Manual/assets/vre.md"
        ],
        "Model" => "Manual/Model.md"
    ],
    "How to contribute" => "how_to_contribute.md",
    "References" => [
        "Introduction" => "References/1_introduction.md",
        "Reading input data" => "References/2_reading_input.md",
        "Macro Objects" => "References/3_macro_objects.md",
        "Writing output data" => "References/4_writing_output.md",
        "Utilities" => "References/5_utilities.md",
        "Downloading examples" => "References/ref_download_examples.md",
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
    repo="github.com/macroenergy/MacroEnergy.jl.git",
    target="build",
    branch="gh-pages",
    devbranch="main",
    devurl="dev",
    push_preview=true,
)


