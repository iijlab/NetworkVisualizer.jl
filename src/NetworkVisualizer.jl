module NetworkVisualizer

#SECTION - Imports
import Base.Filesystem: cp, rm, mkpath
import Oxygen: serve, staticfiles
import Pkg.Artifacts: artifact_hash, artifact_path, ensure_artifact_installed
import TestItems: @testitem

#SECTION - Exports
export start_server

#SECTION - Includes

# Artifacts handling
include("artifacts.jl")

# Server configuration
include("server.jl")

#SECTION - Main function (optional)

end
