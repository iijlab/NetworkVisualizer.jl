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
Setup routes for network data API with integrated plotting
"""
function setup_network_routes(assets_dir::String; network_provider = nothing)
    # Create API router
    api = router("/api", tags = ["network-api"])

    # Initialize plotting
    NetworkPlots.init()

    # Determine the appropriate provider
    provider = if isnothing(network_provider)
        MockNetworkGenerator.create_mock_network_provider()
    else
        network_provider
    end

    # GET /api/networks/{id} - Full network data
    get(api("/networks/{id}")) do req::HTTP.Request, id::String
        @info "Network data requested" network_id=id
        try
            data = provider(id, :data)

            # Create/update plots for all resources
            for node in data.nodes
                @info "Processing node" node_id=node.id history_length=length(node.metrics.history)

                plot_response = NetworkPlots.plot_metrics(node.id, node.metrics.history)
                if !isnothing(plot_response)
                    # Get the HTML string and make sure it's properly encoded
                    plot_html = String(plot_response.body)
                    # Update the metrics dictionary directly
                    node.metrics.current["historyPlot"] = plot_html
                    @info "Plot HTML assigned for node" node_id=node.id plot_sample=plot_html[1:min(
                        100, length(plot_html),)]
                end
            end

            for link in data.links
                link_id = "$(link.source)->$(link.target)"
                @info "Processing link" link_id=link_id history_length=length(link.metrics.history)

                plot_response = NetworkPlots.plot_metrics(link_id, link.metrics.history)
                if !isnothing(plot_response)
                    # Get the HTML string and make sure it's properly encoded
                    plot_html = String(plot_response.body)
                    # Update the metrics dictionary directly
                    link.metrics.current["historyPlot"] = plot_html
                    @info "Plot HTML assigned for link" link_id=link_id plot_sample=plot_html[1:min(
                        100, length(plot_html),)]
                end
            end

            # Log a sample of the final JSON response
            response_json = JSON3.write(data)
            @info "Response prepared" sample_length=min(1000, length(response_json)) sample=response_json[1:min(
                1000, length(response_json),)]

            return json(data)
        catch e
            @error "Error generating network data" network_id=id exception=(
                e, catch_backtrace(),)
            return Response(500, "Error generating network data")
        end
    end

    # GET /api/networks/{id}/updates - Network updates
    get(api("/networks/{id}/updates")) do req::HTTP.Request, id::String
        @info "Network updates requested" network_id=id
        try
            network_updates = provider(id, :update)::NetworkUpdates

            # Update plots with new data points
            for (node_id, node_update) in network_updates.changes.nodes
                metrics = get(node_update, "metrics", nothing)
                if !isnothing(metrics)
                    current = get(metrics, "current", nothing)
                    if !isnothing(current)
                        timestamp = DateTime(current["timestamp"], "yyyy-mm-ddTHH:MM:SSZ")
                        value = current["allocation"]

                        plot_response = NetworkPlots.add_point!(node_id, timestamp, value)
                        if !isnothing(plot_response)
                            metrics["current"]["historyPlot"] = String(plot_response.body)
                        end
                    end
                end
            end

            for (link_id, link_update) in network_updates.changes.links
                metrics = get(link_update, "metrics", nothing)
                if !isnothing(metrics)
                    current = get(metrics, "current", nothing)
                    if !isnothing(current)
                        timestamp = DateTime(current["timestamp"], "yyyy-mm-ddTHH:MM:SSZ")
                        value = current["allocation"]

                        plot_response = NetworkPlots.add_point!(link_id, timestamp, value)
                        if !isnothing(plot_response)
                            metrics["current"]["historyPlot"] = String(plot_response.body)
                        end
                    end
                end
            end

            return json(network_updates)
        catch e
            @error "Error generating network updates" network_id=id exception=(
                e, catch_backtrace(),)
            return Response(500, "Error generating network updates")
        end
    end

    # GET /api/config - Get network configuration
    get(api("/config")) do req::HTTP.Request
        @info "Config endpoint called"
        config_path = joinpath(assets_dir, "data", "config.json")

        try
            if isfile(config_path)
                content = read(config_path, String)
                return json(JSON3.read(content))
            end
        catch e
            @error "Error reading config file" error=e
        end

        # Return default config if file not found or error occurs
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

    @info "Routes setup completed"
end
