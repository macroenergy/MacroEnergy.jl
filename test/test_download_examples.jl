module TestDownloadExamples

using Test
using MacroEnergy

@testset "Example repository refs" begin
    current_version = MacroEnergy.macroenergy_version()

    @test MacroEnergy.example_version_tag("0.1.2") == "v0.1.2"
    @test MacroEnergy.example_version_tag("v0.1.2") == "v0.1.2"
    @test MacroEnergy.example_version_tag(v"0.1.2") == "v0.1.2"
    @test MacroEnergy.example_release_branch(v"0.1.2") == "release-0.1"
    @test MacroEnergy.examples_refs(branch="release-0.1") == ["release-0.1"]
    @test MacroEnergy.examples_refs(version=v"0.1.2") == ["v0.1.2"]
    @test MacroEnergy.examples_refs() == [
        MacroEnergy.example_version_tag(current_version),
        MacroEnergy.example_release_branch(current_version),
    ]
    @test_throws ErrorException MacroEnergy.examples_refs(branch="main", version="0.1.2")
end

end # module TestDownloadExamples
