"""
Create a network provider that reads from the frontend artifact's data directory
"""
function create_frontend_network_provider(artifact_dir::String)
    networks_dir = joinpath(artifact_dir, "data", "networks")

    return function (network_id::String)
        file_path = joinpath(networks_dir, "$(network_id).json")

        if !isfile(file_path)
            @warn "Network data file not found: $file_path"
            return NetworkData(
                NetworkMetadata(network_id),
                NetworkNode[],
                NetworkLink[],
            )
        end

        try
            # Read file content as string first
            content = read(file_path, String)
            # Then parse JSON
            return JSON3.read(content, NetworkData)
        catch e
            @error "Error reading network data" network_id=network_id error=e
            return NetworkData(
                NetworkMetadata(network_id),
                NetworkNode[],
                NetworkLink[],
            )
        end
    end
end

"""
Create a network provider that reads from JSON files
"""
function create_json_network_provider(data_dir::String)
    return function (network_id::String)
        file_path = joinpath(data_dir, "networks", "$(network_id).json")

        if !isfile(file_path)
            @warn "Network data file not found: $file_path"
            # Return empty network with basic metadata
            return NetworkData(
                NetworkMetadata(network_id),
                NetworkNode[],
                NetworkLink[],
            )
        end

        try
            # Read file content as string first
            content = read(file_path, String)
            # Then parse JSON
            return JSON3.read(content, NetworkData)
        catch e
            @error "Error reading network data" network_id=network_id error=e
            return NetworkData(
                NetworkMetadata(network_id),
                NetworkNode[],
                NetworkLink[],
            )
        end
    end
end
