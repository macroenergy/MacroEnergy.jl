using Macro

# Delete existing GenX results, run Genx, then run Macro and compare
genx_results = joinpath(@__DIR__, "three_zones_genx", "results")
if isdir(genx_results)
    rm(genx_results; recursive = true)
end
# Run garbage collection to try make comparisons more fair
GC.gc() 
genx_memory = @allocated include(joinpath(@__DIR__, "three_zones_genx", "run.jl"))
genx_meminfo = Macro.meminfo()
GC.gc()
macro_memory = @allocated include(joinpath(@__DIR__, "three_zones_macro_genx", "run.jl"))
macro_meminfo = Macro.meminfo()

println("GenX memory info:")
Macro.print_meminfo(genx_meminfo)
println("Macro memory info:")
Macro.print_meminfo(macro_meminfo)
println("GenX allocations: $(genx_memory/1e9) GB")
println("Macro allocations: $(macro_memory/1e9) GB")
