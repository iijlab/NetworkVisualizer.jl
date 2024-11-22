"""
Get the frontend artifact's data directory
"""
function get_frontend_data_dir()
    # First, try to find the data directory in the development environment
    dev_data_dir = joinpath(@__DIR__, "..", "assets", "data")
    if isdir(dev_data_dir)
        return dirname(dev_data_dir)
    end

    # If not found, use the artifact directory
    artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    if !isfile(artifacts_toml)
        error("Artifacts.toml not found")
    end

    frontend_hash = artifact_hash("frontend", artifacts_toml)
    if frontend_hash === nothing
        error("Frontend artifact not found")
    end

    artifact_dir = artifact_path(frontend_hash)
    release_dir = only(readdir(artifact_dir))
    return joinpath(artifact_dir, release_dir)
end

"""
Setup routes for network data API
"""
function setup_network_routes(artifact_dir::String; network_provider = nothing)
    # If no custom provider is given, use the frontend data provider
    default_provider = create_frontend_network_provider(artifact_dir)
    active_provider = isnothing(network_provider) ? default_provider : network_provider

    # GET /data/config.json - Network configuration
    get("/data/config.json") do
        config_path = joinpath(artifact_dir, "data", "config.json")
        if isfile(config_path)
            return JSON3.read(read(config_path))
        end

        # Fallback configuration if file not found
        return Dict(
            "nodes" => Dict(
                "leaf" => Dict("radius" => 8, "strokeWidth" => 2),
                "cluster" => Dict("radius" => 12, "strokeWidth" => 3),
            ),
            "links" => Dict("width" => 5, "arrowSize" => 5),
            "colors" => Dict(
                "ranges" => [
                Dict("max" => 0, "color" => "#006994"),
                Dict("max" => 45, "color" => "#4CAF50"),
                Dict("max" => 55, "color" => "#FFC107"),
                Dict("max" => 75, "color" => "#FF9800"),
                Dict("max" => 100, "color" => "#f44336"),
            ]
            ),
        )
    end

    # GET /data/networks/{id}.json - Network data
    get("/data/networks/:id.json") do request
        network_id = request.params[:id]
        return active_provider(network_id)
    end
end
