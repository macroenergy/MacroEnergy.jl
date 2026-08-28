Base.@kwdef struct TDRAutoencoderSequentialSettings <: AbstractTDRMethodSettings
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
end

function tdr_method_settings_data(method_settings::TDRAutoencoderSequentialSettings)
    data = invoke(tdr_method_settings_data, Tuple{AbstractTDRMethodSettings}, method_settings)
    merge!(data, tdr_autoencoder_settings_data(method_settings))
    return data
end

function tdr_method_setup(
    method_settings::TDRAutoencoderSequentialSettings,
    settings::TDRSettings,
)
    return tdr_autoencoder_method_setup(method_settings, settings)
end

tdr_method_name(::TDRAutoencoderSequentialSettings) = :autoencoder_sequential

function tdr_method_settings(
    ::Val{:autoencoder_sequential},
    settings_data::AbstractDict,
    restarts::Int,
    verbose::Bool,
)
    return TDRAutoencoderSequentialSettings(
        ;
        restarts,
        verbose,
        tdr_autoencoder_settings(settings_data)...,
    )
end
