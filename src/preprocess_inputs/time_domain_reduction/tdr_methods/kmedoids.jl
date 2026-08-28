Base.@kwdef struct TDRKMedoidsSettings <: AbstractTDRMethodSettings
    restarts::Int = 0
    verbose::Bool = false
end

tdr_method_name(::TDRKMedoidsSettings) = :kmedoids

tdr_method_settings(::Val{:kmedoids}, settings_data::AbstractDict, restarts::Int, verbose::Bool) =
    TDRKMedoidsSettings(restarts=restarts, verbose=verbose)
