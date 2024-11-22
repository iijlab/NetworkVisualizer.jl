"""
Start the network visualizer server with basic static file serving.
"""
function start_server(; host::String = "0.0.0.0", port::Int = 8080)
    # Setup frontend assets
    assets_dir = setup_frontend_assets()

    # Serve static files at root path
    staticfiles(assets_dir, "/")

    # Start server
    @info "Starting NetworkVisualizer server on $host:$port"
    serve(; host, port)
end
