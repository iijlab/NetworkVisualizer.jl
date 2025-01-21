# Handles mock data generation and storage
module MockNetworkGenerator

using Dates, Random, CSV, DataFrames
import ..NetworkVisualizer: NetworkData, NetworkMetadata, NetworkNode, NetworkLink,
                            MetricData, NetworkUpdates
import JSON3  # Added import

export generate_updates

# Configuration for data storage
const DATA_DIR = joinpath(@__DIR__, "..", "data")

# Ensure directories exist
function init_directories()
    mkpath(joinpath(DATA_DIR, "metrics"))
end

# Save metric data to CSV
function save_metrics(id::String, metrics::Vector{Dict{String, Any}})
    df = DataFrame(
        timestamp = [DateTime(m["timestamp"], "yyyy-mm-ddTHH:MM:SSZ") for m in metrics],
        allocation = [Float64(m["allocation"]) for m in metrics],
    )
    CSV.write(joinpath(DATA_DIR, "metrics", "$(id).csv"), df)
end

# Load metric data from CSV
function load_metrics(id::String)
    file_path = joinpath(DATA_DIR, "metrics", "$(id).csv")
    if !isfile(file_path)
        @info "No metrics file found" file_path=file_path
        return Dict{String, Any}[]
    end

    try
        @info "Loading metrics from CSV" file_path=file_path
        df = CSV.read(file_path, DataFrame)

        # Check if we have the required columns
        if !all(in(["timestamp", "allocation"]), names(df))
            @error "Missing required columns in metrics CSV" columns=names(df)
            return Dict{String, Any}[]
        end

        # Convert to array of dictionaries
        metrics = [Dict{String, Any}(
                       "timestamp" => Dates.format(t, "yyyy-mm-ddTHH:MM:SSZ"),
                       "allocation" => Float64(a),
                   )
                   for (t, a) in zip(df.timestamp, df.allocation)]

        @info "Loaded metrics successfully" num_records=length(metrics)
        return metrics
    catch e
        @error "Error loading metrics from CSV" error=e
        return Dict{String, Any}[]
    end
end
# Evolution pattern for generating mock data
struct EvolutionPattern
    frequency::Float64
    phase::Float64
    base_value::Float64
    amplitude::Float64
    noise_amplitude::Float64
    noise_frequency::Float64
end

# Create new evolution pattern
function create_evolution_pattern(initial_value::Float64 = 50.0)
    EvolutionPattern(
        0.2 + rand() * 0.3,
        rand() * 2π,
        initial_value,
        15.0 + rand() * 25.0,
        5.0 + rand() * 10.0,
        0.8 + rand() * 0.4,
    )
end

# Calculate metric value based on time and pattern
function calculate_value(pattern::EvolutionPattern, elapsed_seconds::Float64)
    main_wave = pattern.amplitude *
                sin(2π * pattern.frequency * elapsed_seconds + pattern.phase)
    noise = pattern.noise_amplitude *
            sin(2π * pattern.noise_frequency * elapsed_seconds)
    return clamp(pattern.base_value + main_wave + noise, 0.0, 100.0)
end

# Generate alerts based on metric value
function generate_alerts(value::Float64)
    alerts = Dict{String, Any}[]
    timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SSZ")

    if value >= 90.0
        push!(alerts,
            Dict(
                "type" => "critical",
                "message" => "allocation critically high: $(round(value, digits=1))%",
                "timestamp" => timestamp,
            ),)
    elseif value >= 75.0
        push!(alerts,
            Dict(
                "type" => "warning",
                "message" => "allocation warning: $(round(value, digits=1))%",
                "timestamp" => timestamp,
            ),)
    end

    return alerts
end

# State management for network data generation
mutable struct NetworkState
    data::NetworkData
    last_update::DateTime
    evolution_patterns::Dict{String, EvolutionPattern}
end

# Initialize patterns for new network
function initialize_patterns(network::NetworkData)
    patterns = Dict{String, EvolutionPattern}()

    # Initialize nodes
    for node in network.nodes
        @info "Initializing node patterns" node_id=node.id
        history = load_metrics(node.id)
        @info "Loaded node history" node_id=node.id history_length=length(history)

        current_value = if !isempty(history)
            Float64(history[end]["allocation"])
        else
            Float64(get(node.metrics.current, "allocation", 50.0))
        end

        patterns[node.id] = create_evolution_pattern(current_value)
    end

    # Initialize links
    for link in network.links
        link_id = "$(link.source)->$(link.target)"
        @info "Initializing link patterns" link_id=link_id

        history = load_metrics(link_id)
        @info "Loaded link history" link_id=link_id history_length=length(history)

        current_value = if !isempty(history)
            Float64(history[end]["allocation"])
        else
            Float64(get(link.metrics.current, "allocation", 50.0))
        end

        patterns[link_id] = create_evolution_pattern(current_value)
    end

    return patterns
end

# Update metrics with new values
function update_metrics(state::NetworkState)
    elapsed = Float64(Dates.value(now() - state.last_update)) / 1000.0
    timestamp = Dates.format(now(), "yyyy-mm-ddTHH:MM:SSZ")

    # Update nodes
    new_nodes = map(state.data.nodes) do node
        pattern = state.evolution_patterns[node.id]
        new_value = calculate_value(pattern, elapsed)

        # Update history
        history = vcat(node.metrics.history,
            Dict("timestamp" => timestamp, "allocation" => new_value),)
        if length(history) > 50  # Keep last 50 points
            history = history[2:end]
        end

        # Save metrics to CSV
        save_metrics(node.id, history)

        metrics = MetricData(
            Dict{String, Any}(
                "allocation" => new_value,
                "timestamp" => timestamp,
            ),
            history,
            generate_alerts(new_value),
        )

        NetworkNode(node.id, node.x, node.y, node.type, node.childNetwork, metrics)
    end

    # Update links
    new_links = map(state.data.links) do link
        link_id = "$(link.source)->$(link.target)"
        pattern = state.evolution_patterns[link_id]
        new_value = calculate_value(pattern, elapsed)

        # Update history
        history = vcat(link.metrics.history,
            Dict("timestamp" => timestamp, "allocation" => new_value),)
        if length(history) > 50
            history = history[2:end]
        end

        # Save metrics to CSV
        save_metrics(link_id, history)

        metrics = MetricData(
            Dict{String, Any}(
                "allocation" => new_value,
                "capacity" => get(link.metrics.current, "capacity", 100.0),
                "timestamp" => timestamp,
            ),
            history,
            generate_alerts(new_value),
        )

        NetworkLink(link.source, link.target, metrics)
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

# Network provider factory
function create_mock_network_provider()
    network_states = Dict{String, NetworkState}()
    init_directories()

    function get_network(network_id::String)
        if !haskey(network_states, network_id)
            network_path = joinpath("assets", "data", "networks", "$(network_id).json")
            if !isfile(network_path)
                error("Network data file not found: $network_path")
            end
            data = JSON3.read(read(network_path), NetworkData)
            patterns = initialize_patterns(data)
            network_states[network_id] = NetworkState(data, now(), patterns)
        end
        return network_states[network_id]
    end

    function provider(network_id::String, kind::Symbol = :data)
        state = get_network(network_id)
        if kind == :update
            old_data = state.data
            new_data = update_metrics(state)
            state.data = new_data
            state.last_update = now()
            return generate_updates(old_data, new_data)
        else
            state.data = update_metrics(state)
            state.last_update = now()
            return state.data
        end
    end

    return provider
end

# Function to generate network updates by comparing old and new states
function generate_updates(old_data::NetworkData, new_data::NetworkData)
    node_changes = Dict{String, Any}()
    link_changes = Dict{String, Any}()

    # Compare nodes
    for (old_node, new_node) in zip(old_data.nodes, new_data.nodes)
        if old_node.metrics.current != new_node.metrics.current ||
           old_node.metrics.history != new_node.metrics.history ||
           old_node.metrics.alerts != new_node.metrics.alerts
            node_changes[new_node.id] = Dict{String, Any}(
                "metrics" => Dict{String, Any}(
                "current" => new_node.metrics.current,
                "history" => new_node.metrics.history,
                "alerts" => new_node.metrics.alerts,
            )
            )
        end
    end

    # Compare links
    for (old_link, new_link) in zip(old_data.links, new_data.links)
        if old_link.metrics.current != new_link.metrics.current ||
           old_link.metrics.history != new_link.metrics.history ||
           old_link.metrics.alerts != new_link.metrics.alerts
            link_id = "$(new_link.source)->$(new_link.target)"
            link_changes[link_id] = Dict{String, Any}(
                "metrics" => Dict{String, Any}(
                "current" => new_link.metrics.current,
                "history" => new_link.metrics.history,
                "alerts" => new_link.metrics.alerts,
            )
            )
        end
    end

    return NetworkUpdates(
        new_data.metadata.lastUpdated,
        (nodes = node_changes, links = link_changes),
    )
end

end # module
