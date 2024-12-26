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
function setup_network_routes(assets_dir::String; network_provider = nothing)
    # Create API router
    api = router("/api", tags = ["network-api"])

    # Determine the appropriate provider based on input
    provider = if isnothing(network_provider)
        MockNetworkGenerator.create_mock_network_provider()
    else
        network_provider
    end

    # GET /api/test - Debug route
    get(api("/test")) do req
        json(Dict("status" => "API routes are working"))
    end

    # GET /api/config - Network configuration
    get(api("/config")) do req
        @info "Config endpoint called"
        config_path = joinpath(assets_dir, "data", "config.json")

        if isfile(config_path)
            return json(JSON3.read(read(config_path)))
        end

        @info "Using fallback config"
        return json(Dict(
            "nodes" => Dict(
                "leaf" => Dict("radius" => 8, "strokeWidth" => 2),
                "cluster" => Dict("radius" => 12, "strokeWidth" => 3),
            ),
            "links" => Dict("width" => 5, "arrowSize" => 5),
            "visualization" => Dict(
                "metric" => "allocation",
                "ranges" => [
                    Dict("max" => 0, "color" => "#006994"),
                    Dict("max" => 45, "color" => "#4CAF50"),
                    Dict("max" => 55, "color" => "#FFC107"),
                    Dict("max" => 75, "color" => "#FF9800"),
                    Dict("max" => 100, "color" => "#f44336"),
                ],
            ),
        ))
    end

    # GET /api/networks/{id} - Full network data
    get(api("/networks/{id}")) do req, id::String
        @info "Network data requested" network_id=id
        try
            data = provider(id, :data)
            @info "Network data generated successfully" network_id=id
            return json(data)
        catch e
            @error "Error generating network data" network_id=id exception=(
                e, catch_backtrace(),)
            return Oxygen.Response(500, "Error generating network data")
        end
    end

    # GET /api/networks/{id}/updates - Network updates
    get(api("/networks/{id}/updates")) do req, id::String
        @info "Network updates requested" network_id=id
        try
            updates = provider(id, :update)
            @info "Network updates generated successfully" network_id=id
            return json(updates)
        catch e
            @error "Error generating network updates" network_id=id exception=(
                e, catch_backtrace(),)
            return Oxygen.Response(500, "Error generating network updates")
        end
    end

    @info "Routes setup completed" routes=[
        "GET /api/test",
        "GET /api/config",
        "GET /api/networks/:id",
        "GET /api/networks/:id/updates",
        "GET /",  # Static files
    ]
end
