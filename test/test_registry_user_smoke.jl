module TestRegistryUserSmoke

using Test

"""
Run a registry-user-style smoke test in a fresh Julia environment.

This test is gated behind `ME_RUN_REGISTRY_SMOKE=true` to avoid slowing normal test runs.
It simulates an external user by activating a temporary project in a new Julia process,
developing MacroEnergy from the local checkout, loading user additions, and loading a case.
"""
function test_registry_user_smoke()
    repo_root = abspath(joinpath(@__DIR__, ".."))

    smoke_script = """
    using Pkg
    Pkg.activate(temp=true)
    Pkg.develop(path=raw\"$repo_root\")

    using MacroEnergy
    examples_dir = mktempdir()
    MacroEnergy.download_example("multisector_3zone", examples_dir)
    case_path = joinpath(examples_dir, "multisector_3zone")
    isdir(case_path) || error("Downloaded case path not found: " * case_path)

    MacroEnergy.create_user_additions_module(case_path)
    MacroEnergy.load_user_additions(case_path)
    MacroEnergy.load_case(case_path)
    """

    cmd = `$(Base.julia_cmd()) --startup-file=no --history-file=no -e $smoke_script`
    @test success(cmd)
    return nothing
end

function should_run_registry_smoke_tests()
    flag = lowercase(strip(get(ENV, "ME_RUN_REGISTRY_SMOKE", "false")))
    return flag in ("1", "true", "yes", "on")
end

if should_run_registry_smoke_tests()
    @testset "Registry-user smoke" begin
        test_registry_user_smoke()
    end
else
    @info "Skipping registry-user smoke test. Set ME_RUN_REGISTRY_SMOKE=true to enable."
end

end # module TestRegistryUserSmoke
