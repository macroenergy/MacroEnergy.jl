struct TDRKMeansSettings <: AbstractTDRMethodSettings
    restarts::Int
    verbose::Bool

    function TDRKMeansSettings(; restarts::Integer=0, verbose::Bool=false)
        restarts >= 0 || throw(ArgumentError("TDR `restarts` must be non-negative."))
        new(Int(restarts), verbose)
    end
end

tdr_method_name(::TDRKMeansSettings) = :kmeans

tdr_method_settings(::Val{:kmeans}, keyword_arguments::Dict{Symbol,Any}) =
    TDRKMeansSettings(; keyword_arguments...)
