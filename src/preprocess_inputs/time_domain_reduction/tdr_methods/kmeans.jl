Base.@kwdef struct TDRKMeansSettings <: AbstractTDRMethodSettings
    restarts::Int = 0
    verbose::Bool = false
end

tdr_method_name(::TDRKMeansSettings) = :kmeans

tdr_method_settings(::Val{:kmeans}, settings_data::AbstractDict, restarts::Int, verbose::Bool) =
    TDRKMeansSettings(restarts=restarts, verbose=verbose)
