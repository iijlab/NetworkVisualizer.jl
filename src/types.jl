# Types to represent network data
struct MetricData
    current::Dict{String, Any}    # Holds current metric values and timestamp
    history::Vector{Dict{String, Any}}  # Historical metrics
    alerts::Vector{Dict{String, Any}}   # Current alerts
end

struct NetworkMetadata
    id::String
    parentNetwork::Union{String, Nothing}
    description::Union{String, Nothing}
    lastUpdated::String  # ISO 8601 timestamp
    updateInterval::Int  # milliseconds
    retentionPeriod::Int  # seconds
end

function NetworkMetadata(id::String, parentNetwork::Union{String, Nothing} = nothing,
        description::Union{String, Nothing} = nothing,)
    lastUpdated = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SSZ")
    return NetworkMetadata(id, parentNetwork, description, lastUpdated, 5000, 3600)
end

struct NetworkNode
    id::String
    x::Float64
    y::Float64
    type::String  # "cluster" or "leaf"
    childNetwork::Union{String, Nothing}
    metrics::MetricData
end

struct NetworkLink
    source::String
    target::String
    metrics::MetricData
end

struct NetworkData
    metadata::NetworkMetadata
    nodes::Vector{NetworkNode}
    links::Vector{NetworkLink}
end

# Define a struct for network updates
struct NetworkUpdates
    timestamp::String
    changes::NamedTuple{(:nodes, :links), Tuple{Dict{String, Any}, Dict{String, Any}}}
end
