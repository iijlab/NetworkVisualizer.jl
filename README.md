# NetworkVisualizer

[![Build Status](https://github.com/iijlab/NetworkVisualizer.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/iijlab/NetworkVisualizer.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/iijlab/NetworkVisualizer.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/iijlab/NetworkVisualizer.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A network visualization tool for hierarchical network structures with real-time updates and dynamic metrics.

## Quick Start

Open Julia REPL and follow these steps:

- Clone the repository:

```julia
] dev https://github.com/iijlab/NetworkVisualizer.jl
```

- Change to the package directory:

- Start the visualization with mock data:

```julia
using NetworkVisualizer
start_server(mock=true)
```

- Open your browser and navigate to `http://127.0.0.1:8080`

You should now see an interactive network visualization with:

- Hierarchical network structure
- Real-time metric updates
- Dynamic clustering
- Interactive node and link details

The mock data provides a realistic simulation of network metrics that updates automatically. Click on cluster nodes (larger circles) to explore nested networks.

## Features

- Interactive network visualization
- Real-time metric updates
- Hierarchical network structure
- Detailed node and link information
- Color-coded metric visualization
- Responsive layout
- Dark/light theme support

## Development

For development purposes, the mock server provides simulated data that matches the structure and behavior of a real network monitoring system. The mock data is generated based on predefined network structures in the `assets/data/networks` directory.

All assets are served from the `assets` directory, and the frontend automatically updates based on the mock data provided through the API endpoints.
