module NetworkVisualizer

#SECTION - Imports
import TestItems: @testitem

#SECTION - Exports
export start_server, NetworkData, Node, Link, Config

#SECTION - Includes

# Include type definitions
include("types.jl")

# Include API routes
include("api.jl")

# Include utility functions
include("utils.jl")

# Include server configuration
include("server.jl")

#SECTION - Main function (optional)

end
