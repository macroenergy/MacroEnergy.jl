include("kmeans.jl")
include("kmedoids.jl")
include("autoencoder_sequential.jl")
include("autoencoder_simultaneous.jl")

function tdr_method_settings(
    method::Val,
    settings_data::AbstractDict,
    restarts::Int,
    verbose::Bool,
)::AbstractTDRMethodSettings
    throw(ArgumentError(
        "TDR `method.name` must be `kmeans`, `kmedoids`, `autoencoder_sequential`, or `autoencoder_simultaneous`; received `$(typeof(method).parameters[1])`.",
    ))
end
