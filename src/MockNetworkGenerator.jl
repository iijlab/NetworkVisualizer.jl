module MockNetworkGenerator

using Dates, Random
import ..NetworkVisualizer: NetworkData, NetworkMetadata, NetworkNode, NetworkLink,
                            MetricData
import JSON3

"""
Stores the previous state to generate meaningful updates
"""
mutable struct NetworkState
    data::NetworkData
    last_update::DateTime
end

"""
Update metrics with random variations
"""
function update_metrics(network::NetworkData)
    timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SSZ")

    # Update nodes with small random changes
    new_nodes = map(network.nodes) do node
        old_value = get(node.metrics.current, "allocation", 50.0)
        # Add small random variation (-2 to +2)
        new_value = clamp(old_value + (rand() - 0.5) * 4, 0, 100)

        metrics = MetricData(
            Dict{String, Any}(
                "allocation" => new_value,
                "timestamp" => timestamp,
            ),
            node.metrics.history,
            node.metrics.alerts,
        )

        NetworkNode(
            node.id,
            node.x,
            node.y,
            node.type,
            node.childNetwork,
            metrics,
        )
    end

    # Update links with small random changes
    new_links = map(network.links) do link
        old_value = get(link.metrics.current, "allocation", 50.0)
        old_capacity = get(link.metrics.current, "capacity", 100.0)

        # Add small random variation (-2 to +2)
        new_value = clamp(old_value + (rand() - 0.5) * 4, 0, 100)

        metrics = MetricData(
            Dict{String, Any}(
                "allocation" => new_value,
                "capacity" => old_capacity,
                "timestamp" => timestamp,
            ),
            link.metrics.history,
            link.metrics.alerts,
        )

        NetworkLink(
            link.source,
            link.target,
            metrics,
        )
    end

    # Return updated network with new timestamp
    NetworkData(
        NetworkMetadata(
            network.metadata.id,
            network.metadata.parentNetwork,
            network.metadata.description,
            timestamp,
            network.metadata.updateInterval,
            network.metadata.retentionPeriod,
        ),
        new_nodes,
        new_links,
    )
end

"""
Generate updates by comparing old and new states
"""
function generate_updates(old_data::NetworkData, new_data::NetworkData)
    changes = Dict{String, Any}(
        "nodes" => Dict{String, Any}(),
        "links" => Dict{String, Any}(),
    )

    # Compare and store node changes
    for (old_node, new_node) in zip(old_data.nodes, new_data.nodes)
        if old_node.metrics.current != new_node.metrics.current
            changes["nodes"][new_node.id] = Dict(
                "metrics" => Dict(
                "current" => new_node.metrics.current,
                "alerts" => new_node.metrics.alerts,
            )
            )
        end
    end

    # Compare and store link changes
    for (old_link, new_link) in zip(old_data.links, new_data.links)
        if old_link.metrics.current != new_link.metrics.current
            link_id = "$(new_link.source)->$(new_link.target)"
            changes["links"][link_id] = Dict(
                "metrics" => Dict(
                "current" => new_link.metrics.current,
                "alerts" => new_link.metrics.alerts,
            )
            )
        end
    end

    return Dict(
        "timestamp" => new_data.metadata.lastUpdated,
        "changes" => changes,
    )
end

"""
Creates a network provider with state management that reads initial data from asset files
"""
function create_mock_network_provider()
    # Store network states
    network_states = Dict{String, NetworkState}()

    function get_network(network_id::String)
        if !haskey(network_states, network_id)
            # Try to read initial network data from assets
            network_path = joinpath("assets", "data", "networks", "$(network_id).json")
            if !isfile(network_path)
                error("Network data file not found: $network_path")
            end

            # Parse JSON data into our network types
            data = JSON3.read(read(network_path), NetworkData)
            network_states[network_id] = NetworkState(data, now())
        end
        return network_states[network_id]
    end

    # Return a single provider function that can handle both data and updates
    function provider(network_id::String, kind::Symbol = :data)
        state = get_network(network_id)

        if kind == :update
            old_data = state.data
            new_data = update_metrics(old_data)
            state.data = new_data
            state.last_update = now()
            return generate_updates(old_data, new_data)
        else  # kind == :data
            state.data = update_metrics(state.data)
            state.last_update = now()
            return state.data
        end
    end

    return provider
end

end # module
