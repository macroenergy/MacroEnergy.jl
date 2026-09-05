struct TDRKMedoidsSettings <: AbstractTDRMethodSettings
    restarts::Int
    verbose::Bool

    function TDRKMedoidsSettings(; restarts::Integer=0, verbose::Bool=false)
        restarts >= 0 || throw(ArgumentError("TDR `restarts` must be non-negative."))
        new(Int(restarts), verbose)
    end
end

tdr_method_name(::TDRKMedoidsSettings) = :kmedoids

tdr_method_settings(::Val{:kmedoids}, keyword_arguments::Dict{Symbol,Any}) =
    TDRKMedoidsSettings(; keyword_arguments...)
