# Types to represent network data
struct NetworkMetadata
    id::String
    parentNetwork::Union{String, Nothing}
end

struct NetworkNode
    id::String
    type::String  # "cluster" or "leaf"
    x::Float64
    y::Float64
    allocation::Float64
    childNetwork::Union{String, Nothing}
end

struct NetworkLink
    source::String
    target::String
    allocation::Float64
    capacity::Float64
end

struct NetworkData
    metadata::NetworkMetadata
    nodes::Vector{NetworkNode}
    links::Vector{NetworkLink}
end
