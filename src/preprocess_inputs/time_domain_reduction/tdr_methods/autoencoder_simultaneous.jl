Base.@kwdef struct TDRAutoencoderSimultaneousSettings <: AbstractTDRMethodSettings
    restarts::Int = 0
    verbose::Bool = false
    kernel_size::Int = 3
    stride::Int = 1
    epochs::Int = 50
    min_err_diff::Float64 = 1e-4
    patience::Int = 10
    warmup::Int = 5
    n_filters::Int = 8
    latent_dim::Int = 4
    lambda::Float64 = 0.1
end

function tdr_method_settings_data(method_settings::TDRAutoencoderSimultaneousSettings)
    data = invoke(tdr_method_settings_data, Tuple{AbstractTDRMethodSettings}, method_settings)
    merge!(data, tdr_autoencoder_settings_data(method_settings), Dict("lambda" => method_settings.lambda))
    return data
end

function tdr_method_setup(
    method_settings::TDRAutoencoderSimultaneousSettings,
    settings::TDRSettings,
)
    return tdr_autoencoder_method_setup(method_settings, settings)
end

tdr_method_name(::TDRAutoencoderSimultaneousSettings) = :autoencoder_simultaneous

function tdr_method_settings(
    ::Val{:autoencoder_simultaneous},
    settings_data::AbstractDict,
    restarts::Int,
    verbose::Bool,
)
    return TDRAutoencoderSimultaneousSettings(
        ;
        restarts,
        verbose,
        tdr_autoencoder_settings(settings_data)...,
        lambda=tdr_method_float(settings_data, "lambda", 0.1; minimum=0.0),
    )
end
