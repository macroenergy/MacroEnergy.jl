struct TDRAutoencoderSequentialSettings <: AbstractTDRMethodSettings
    restarts::Int
    verbose::Bool
    kernel_size::Int
    stride::Int
    epochs::Int
    min_err_diff::Float64
    patience::Int
    warmup::Int
    n_filters::Int
    latent_dim::Int

    function TDRAutoencoderSequentialSettings(; restarts::Integer=0, verbose::Bool=false,
        kernel_size::Integer=3, stride::Integer=1, epochs::Integer=50,
        min_err_diff::Real=1e-4, patience::Integer=10, warmup::Integer=5,
        n_filters::Integer=8, latent_dim::Integer=4
    )
        restarts >= 0 || throw(ArgumentError("TDR `restarts` must be non-negative."))
        settings = tdr_validated_autoencoder_settings(;
            kernel_size, stride, epochs, min_err_diff,
            patience, warmup, n_filters, latent_dim
        )
        new(Int(restarts), verbose, settings...)
    end
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
    keyword_arguments::Dict{Symbol,Any},
)
    return TDRAutoencoderSequentialSettings(; keyword_arguments...)
end
