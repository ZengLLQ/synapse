module Config

using Random

struct AppConfig
    base_dir::String
    default_port::Int
    session_token::String
    log_level::String
    allow_cloud_without_consent::Bool
end

function AppConfig(; base_dir::String = get(ENV, "SYNAPSE_DATA_DIR", joinpath(homedir(), ".synapse")),
                   port::Int = parse(Int, get(ENV, "SYNAPSE_PORT", "8765")),
                   default_port::Int = port,
                   session_token::String = get(ENV, "SYNAPSE_SESSION_TOKEN", bytes2hex(rand(UInt8, 32))),
                   log_level::String = get(ENV, "SYNAPSE_LOG_LEVEL", "INFO"),
                   allow_cloud_without_consent::Bool = false)
    return AppConfig(base_dir, default_port, session_token, log_level, allow_cloud_without_consent)
end

function default_config(; base_dir::String = get(ENV, "SYNAPSE_DATA_DIR", joinpath(homedir(), ".synapse")),
                          port::Int = parse(Int, get(ENV, "SYNAPSE_PORT", "8765")),
                          session_token::String = get(ENV, "SYNAPSE_SESSION_TOKEN", bytes2hex(rand(UInt8, 32))),
                          log_level::String = get(ENV, "SYNAPSE_LOG_LEVEL", "INFO"))
    return AppConfig(base_dir, port, session_token, log_level, false)
end

end # module Config
