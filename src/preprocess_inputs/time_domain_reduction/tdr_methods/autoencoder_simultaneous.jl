struct TDRAutoencoderSimultaneousSettings <: AbstractTDRMethodSettings
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
    lambda::Float64

    function TDRAutoencoderSimultaneousSettings(; restarts::Integer=0, verbose::Bool=false,
        kernel_size::Integer=3, stride::Integer=1, epochs::Integer=50,
        min_err_diff::Real=1e-4, patience::Integer=10, warmup::Integer=5,
        n_filters::Integer=8, latent_dim::Integer=4, lambda::Real=0.1
    )
        restarts >= 0 || throw(ArgumentError("TDR `restarts` must be non-negative."))
        isfinite(lambda) && lambda >= 0 || throw(ArgumentError("TDR `lambda` must be finite and non-negative."))
        settings = tdr_validated_autoencoder_settings(;
            kernel_size, stride, epochs, min_err_diff,
            patience, warmup, n_filters, latent_dim
        )
        new(Int(restarts), verbose, settings..., Float64(lambda))
    end
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
    keyword_arguments::Dict{Symbol,Any},
)
    return TDRAutoencoderSimultaneousSettings(; keyword_arguments...)
end
