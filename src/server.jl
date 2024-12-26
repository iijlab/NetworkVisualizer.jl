"""
Start the network visualizer server with both static file serving and dynamic network routes.
"""
function start_server(;
        host::String = "127.0.0.1",
        port::Int = 8080,
        mock::Bool = false,
        network_provider = nothing,
)
    # Setup frontend assets
    assets_dir = setup_frontend_assets()

    # Serve static files from assets directory
    staticfiles(assets_dir, "/")

    # Determine the network provider based on mock flag
    active_provider = if mock
        MockNetworkGenerator.create_mock_network_provider()
    elseif !isnothing(network_provider)
        network_provider
    else
        create_frontend_network_provider(assets_dir)
    end

    # Setup network data routes using the selected provider
    setup_network_routes(assets_dir; network_provider = active_provider)

    # Start server
    @info "Starting NetworkVisualizer server on $host:$port ($(mock ? "mock" : "standard") mode)"
    @info "Serving static files from $assets_dir"
    serve(; host, port)
end
