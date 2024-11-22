module NetworkVisualizer

#SECTION - Imports
import Base.Filesystem: cp, rm, mkpath
import Oxygen: serve, staticfiles
import Pkg.Artifacts: artifact_hash, artifact_path, ensure_artifact_installed
import JSON3: read
import TestItems: @testitem

#SECTION - Exports
export start_server
export NetworkData, NetworkMetadata, NetworkNode, NetworkLink
export create_json_network_provider

#SECTION - Includes
include("types.jl")          # Data structures
include("artifacts.jl")      # Artifact handling
include("providers.jl")      # Network data providers
include("routes.jl")         # Route definitions
include("server.jl")         # Server configuration

end
