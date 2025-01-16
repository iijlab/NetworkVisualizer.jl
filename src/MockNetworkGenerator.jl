# Enhanced mock data generation with wave-like patterns
module MockNetworkGenerator

using Dates, Random
import ..NetworkVisualizer: NetworkData, NetworkMetadata, NetworkNode, NetworkLink,
                            MetricData
import JSON3

# Evolution pattern for a single metric
struct EvolutionPattern
    frequency::Float64      # Oscillation frequency
    phase::Float64         # Phase offset
    base_value::Float64    # Base value around which to oscillate
    amplitude::Float64     # Oscillation amplitude
    noise_amplitude::Float64  # Random noise amplitude
    noise_frequency::Float64  # Noise frequency multiplier
end

# State management for a single network
mutable struct NetworkState
    data::NetworkData
    last_update::DateTime
    evolution_patterns::Dict{String, EvolutionPattern}  # node_id/link_id => pattern
end

"""
Create a new evolution pattern for a metric with more pronounced variations
"""
function create_evolution_pattern(initial_value::Float64 = 50.0)
    EvolutionPattern(
        0.2 + rand() * 0.3,           # frequency: 0.2-0.5 (faster oscillation)
        rand() * 2π,                  # random phase
        initial_value,                # base value
        15.0 + rand() * 25.0,        # amplitude: 15-40 (larger swings)
        5.0 + rand() * 10.0,         # noise amplitude: 5-15 (more noise)
        0.8 + rand() * 0.4,           # noise frequency: 0.8-1.2 (faster noise)
    )
end

"""
Calculate metric value based on time and pattern
"""
function calculate_value(pattern::EvolutionPattern, elapsed_seconds::Float64)
    # Main wave component
    main_wave = pattern.amplitude *
                sin(2π * pattern.frequency * elapsed_seconds + pattern.phase)

    # Noise component
    noise = pattern.noise_amplitude *
            sin(2π * pattern.noise_frequency * elapsed_seconds)

    # Combine and clamp to 0-100 range
    return clamp(pattern.base_value + main_wave + noise, 0.0, 100.0)
end

"""
Generate alerts based on metric value
"""
function generate_alerts(value::Float64; warning_threshold::Float64 = 75.0,
        critical_threshold::Float64 = 90.0,)
    alerts = Dict{String, Any}[]
    timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SSZ")

    if value >= critical_threshold
        push!(alerts,
            Dict(
                "type" => "critical",
                "message" => "allocation critically high: $(round(value, digits=1))%",
                "timestamp" => timestamp,
            ),)
    elseif value >= warning_threshold
        push!(alerts,
            Dict(
                "type" => "warning",
                "message" => "allocation warning: $(round(value, digits=1))%",
                "timestamp" => timestamp,
            ),)
    end

    return alerts
end

"""
Initialize evolution patterns for a network
"""
function initialize_patterns(network::NetworkData)
    patterns = Dict{String, EvolutionPattern}()

    # Create patterns for nodes
    for node in network.nodes
        # Ensure we get a Float64 value
        current_value = Float64(get(node.metrics.current, "allocation", 50.0))
        patterns[node.id] = create_evolution_pattern(current_value)
    end

    # Create patterns for links
    for link in network.links
        link_id = "$(link.source)->$(link.target)"
        # Ensure we get a Float64 value
        current_value = Float64(get(link.metrics.current, "allocation", 50.0))
        patterns[link_id] = create_evolution_pattern(current_value)
    end

    return patterns
end

"""
Update metrics with wave-like patterns
"""
function update_metrics(state::NetworkState)
    elapsed = Float64(Dates.value(now() - state.last_update)) / 1000.0
    timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SSZ")

    # Update nodes
    new_nodes = map(state.data.nodes) do node
        pattern = state.evolution_patterns[node.id]
        new_value = calculate_value(pattern, elapsed)

        metrics = MetricData(
            Dict{String, Any}(
                "allocation" => new_value,
                "timestamp" => timestamp,
            ),
            node.metrics.history,
            generate_alerts(new_value),
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

    # Update links
    new_links = map(state.data.links) do link
        link_id = "$(link.source)->$(link.target)"
        pattern = state.evolution_patterns[link_id]
        new_value = calculate_value(pattern, elapsed)
        old_capacity = get(link.metrics.current, "capacity", 100.0)

        metrics = MetricData(
            Dict{String, Any}(
                "allocation" => new_value,
                "capacity" => old_capacity,
                "timestamp" => timestamp,
            ),
            link.metrics.history,
            generate_alerts(new_value),
        )

        NetworkLink(
            link.source,
            link.target,
            metrics,
        )
    end

    return NetworkData(
        NetworkMetadata(
            state.data.metadata.id,
            state.data.metadata.parentNetwork,
            state.data.metadata.description,
            timestamp,
            state.data.metadata.updateInterval,
            state.data.metadata.retentionPeriod,
        ),
        new_nodes,
        new_links,
    )
end

"""
Generate updates by comparing current and new states
"""
function generate_updates(old_data::NetworkData, new_data::NetworkData)
    changes = Dict{String, Any}(
        "nodes" => Dict{String, Any}(),
        "links" => Dict{String, Any}(),
    )

    # Compare node changes
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

    # Compare link changes
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

    return Dict{String, Any}(
        "timestamp" => new_data.metadata.lastUpdated,
        "changes" => changes,
    )
end

"""
Creates a network provider with state management that reads initial data from asset files
"""
function create_mock_network_provider()
    network_states = Dict{String, NetworkState}()

    function get_network(network_id::String)
        if !haskey(network_states, network_id)
            # Read initial network data from assets
            network_path = joinpath("assets", "data", "networks", "$(network_id).json")
            if !isfile(network_path)
                error("Network data file not found: $network_path")
            end

            # Parse JSON data
            data = JSON3.read(read(network_path), NetworkData)
            patterns = initialize_patterns(data)
            network_states[network_id] = NetworkState(data, now(), patterns)
        end
        return network_states[network_id]
    end

    # Provider function that handles both data and updates
    function provider(network_id::String, kind::Symbol = :data)
        state = get_network(network_id)

        if kind == :update
            old_data = state.data
            new_data = update_metrics(state)
            state.data = new_data
            state.last_update = now()
            return generate_updates(old_data, new_data)
        else # kind == :data
            state.data = update_metrics(state)
            state.last_update = now()
            return state.data
        end
    end

    return provider
end

end # module
