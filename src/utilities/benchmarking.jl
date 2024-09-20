function meminfo()
    return Dict{String, Integer}(
        # "GC total" => Base.gc_total_bytes(Base.gc_num()),
        "GC live" => Base.gc_live_bytes(),
        "JIT" => Base.jit_total_bytes(),
        "Max. RSS" => Sys.maxrss()
    )
end

function print_meminfo(meminfo_data::Dict{String, Integer})
    for (key, value) in meminfo_data
        @printf "%-10s: %9.3f MiB\n" key value/2^20
    end
end