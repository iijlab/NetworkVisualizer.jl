"""
Start the network visualizer server with both static file serving and dynamic network routes.
"""
function start_server(;
        host::String = "0.0.0.0", port::Int = 8080, network_provider = nothing,)
    # Setup frontend assets
    assets_dir = setup_frontend_assets()

    # Setup network data routes using the frontend artifact directory
    setup_network_routes(assets_dir; network_provider)

    # Serve static files at root path
    # Note: this must come after route setup to avoid conflicts
    staticfiles(assets_dir, "/")

    # Start server
    @info "Starting NetworkVisualizer server on $host:$port"
    serve(; host, port)
end
