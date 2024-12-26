module MockNetworkGenerator

using Dates, Random
import ..NetworkVisualizer: NetworkData, NetworkMetadata, NetworkNode, NetworkLink,
                            MetricData

"""
Stores the previous state to generate meaningful updates
"""
mutable struct NetworkState
    data::NetworkData
    last_update::DateTime
end

"""
Create metric data with current values and empty history/alerts
"""
function create_metric_data(value::Float64, timestamp::String)
    MetricData(
        Dict("allocation" => value, "timestamp" => timestamp),
        Vector{Dict{String, Any}}(),  # Empty history
        Vector{Dict{String, Any}}(),   # Empty alerts
    )
end

"""
Generate initial network structure
"""
function generate_initial_network(id::String, parent_id::Union{String, Nothing} = nothing)
    timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SSZ")

    # Create metadata
    metadata = NetworkMetadata(
        id,
        parent_id,
        "Network $id",
        timestamp,
        5000,  # 5 second update interval
        3600,   # 1 hour retention
    )

    # Generate nodes in a circular layout
    num_nodes = rand(3:4)
    nodes = Vector{NetworkNode}()
    for i in 1:num_nodes
        angle = 2π * (i - 1) / num_nodes
        radius = 200.0
        x = radius * cos(angle) + 400
        y = radius * sin(angle) + 300

        is_cluster = rand() < 0.3
        child_network = is_cluster ? "$(id)_$i" : nothing
        node_type = is_cluster ? "cluster" : "leaf"
        initial_allocation = 30.0 + rand() * 40.0

        node = NetworkNode(
            "$(id)_$i",
            x,
            y,
            node_type,
            child_network,
            create_metric_data(initial_allocation, timestamp),
        )
        push!(nodes, node)
    end

    # Generate links
    links = Vector{NetworkLink}()
    for i in 1:num_nodes
        for j in (i + 1):num_nodes
            if rand() < 0.7  # 70% chance of link
                link = NetworkLink(
                    nodes[i].id,
                    nodes[j].id,
                    create_metric_data(30.0 + rand() * 40.0, timestamp),
                )
                push!(links, link)
            end
        end
    end

    NetworkData(metadata, nodes, links)
end

"""
Update metrics with random variations
"""
function update_metrics(network::NetworkData)
    timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SSZ")

    # Update nodes with small random changes
    new_nodes = map(network.nodes) do node
        old_value = get(node.metrics.current, "allocation", 50.0)
        # Add small random variation (-5 to +5)
        new_value = clamp(old_value + (rand() - 0.5) * 10, 0, 100)

        NetworkNode(
            node.id,
            node.x,
            node.y,
            node.type,
            node.childNetwork,
            create_metric_data(new_value, timestamp),
        )
    end

    # Update links with small random changes
    new_links = map(network.links) do link
        old_value = get(link.metrics.current, "allocation", 50.0)
        # Add small random variation (-5 to +5)
        new_value = clamp(old_value + (rand() - 0.5) * 10, 0, 100)

        NetworkLink(
            link.source,
            link.target,
            create_metric_data(new_value, timestamp),
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
Creates a network provider with state management
"""
function create_mock_network_provider()
    # Store network states
    network_states = Dict{String, NetworkState}()

    function get_network(network_id::String)
        if !haskey(network_states, network_id)
            # Generate new network if doesn't exist
            data = generate_initial_network(network_id)
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
