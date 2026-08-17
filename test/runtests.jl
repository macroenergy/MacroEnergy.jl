import Test
using Logging
using MacroEnergy


test_logger = ConsoleLogger(stderr, Logging.Warn)

with_logger(test_logger) do
    Test.@testset verbose = true "Load Inputs" begin
        include("test_workflow.jl")
        include("test_balance_data.jl")
        include("test_supply_inputs.jl")
        include("test_download_examples.jl")
        include("test_user_additions.jl")
        include("test_registry_user_smoke.jl")
        include("test_case_settings.jl")

        Test.@testset "Asset tests" begin
            include("asset_tests/test_assets_transmission_links.jl")
            include("asset_tests/test_asset_thermalpower_balance.jl")
            include("asset_tests/test_asset_electrolyzer_balance.jl")
            include("asset_tests/test_asset_battery_balance.jl")
            include("asset_tests/test_asset_aluminaplant_balance.jl")
            include("asset_tests/test_asset_aluminumrefining_balance.jl")
            include("asset_tests/test_asset_aluminumsmelting_balance.jl")
            include("asset_tests/test_asset_beccselectricity_balance.jl")
            include("asset_tests/test_asset_beccsgasoline_balance.jl")
            include("asset_tests/test_asset_beccshydrogen_balance.jl")
            include("asset_tests/test_asset_beccsliquidfuels_balance.jl")
            include("asset_tests/test_asset_beccsnaturalgas_balance.jl")
            include("asset_tests/test_asset_cementplant_balance.jl")
            include("asset_tests/test_asset_bfbof_balance.jl")
            include("asset_tests/test_asset_bfbofccs_balance.jl")
            include("asset_tests/test_asset_dreaf_balance.jl")
            include("asset_tests/test_asset_dreafccs_balance.jl")
            include("asset_tests/test_asset_co2injection_balance.jl")
            include("asset_tests/test_asset_downstreamemissions_balance.jl")
            include("asset_tests/test_asset_upstreamemissions_balance.jl")
            include("asset_tests/test_asset_electricdac_balance.jl")
            include("asset_tests/test_asset_natgasdac_balance.jl")
            include("asset_tests/test_asset_fuelcell_balance.jl")
            include("asset_tests/test_asset_thermalhydrogen_balance.jl")
            include("asset_tests/test_asset_thermalhydrogenccs_balance.jl")
            include("asset_tests/test_asset_thermalpowerccs_balance.jl")
            include("asset_tests/test_asset_syntheticammonia_balance.jl")
            include("asset_tests/test_asset_thermalammonia_balance.jl")
            include("asset_tests/test_asset_thermalammoniaccs_balance.jl")
            include("asset_tests/test_asset_syntheticmethanol_balance.jl")
            include("asset_tests/test_asset_thermalmethanol_balance.jl")
            include("asset_tests/test_asset_thermalmethanolccs_balance.jl")
            include("asset_tests/test_asset_syntheticliquidfuels_balance.jl")
            include("asset_tests/test_asset_syntheticnaturalgas_balance.jl")
            include("asset_tests/test_asset_thermalheating_balance.jl")
            include("asset_tests/test_asset_thermalsteam_balance.jl")
            include("asset_tests/test_asset_electricheating_balance.jl")
            include("asset_tests/test_asset_electricsteam_balance.jl")
            include("asset_tests/test_asset_gasstorage_balance.jl")
            include("asset_tests/test_asset_hydrores_balance.jl")
            include("asset_tests/test_asset_mustrun_balance.jl")
            include("asset_tests/test_asset_electricarcfurnace_balance.jl")
            include("asset_tests/test_asset_vre_balance.jl")
        end
    end

    Test.@testset verbose = true "Annualized Costs" begin
        include("test_annualized_costs.jl")
    end

    Test.@testset verbose = true "Writing Outputs" begin
        include("test_output.jl")
        include("test_full_timeseries.jl")
    end
    
    Test.@testset verbose = true "Dual Value Exports" begin
        include("test_duals.jl")
    end
    
    Test.@testset verbose = true "Benders Output Utilities" begin
        include("test_benders_output_utilities.jl")
    end
    
    Test.@testset verbose = true "Myopic Functionality" begin
        include("test_myopic.jl")
    end

    Test.@testset verbose = true "Container Types and Accessors" begin
        include("test_container_types.jl")
        include("test_accessor_allocation.jl")
        include("test_node_supply_accessors.jl")
    end
    return nothing
end
