module TestConfig

using Macro
using Test


settings_path = joinpath(@__DIR__, "test_inputs/settings/macro_settings.yml")

function test_configure_settings(settings_path::String)
    settings = configure_settings(settings_path)

    @test settings[:UCommit] == true
    @test settings[:NetworkExpansion] == true

    return nothing
end

test_configure_settings(settings_path)

end # module TestConfig
