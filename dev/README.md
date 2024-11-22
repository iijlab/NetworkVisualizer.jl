# Development Tools

This directory contains tools for managing the NetworkVisualizer.jl development environment.

## Frontend Artifact Management

To generate an Artifacts.toml entry for a new frontend release:

```bash
cd dev
# First time only: install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Generate entry for a specific version
julia --project=. update_frontend.jl 0.1.0  # or v0.1.0
```

This will:

1. Download the frontend release tarball
2. Compute required hashes
3. Generate the Artifacts.toml entry

The output can be directly copied into the root Artifacts.toml file.

## Files

```bash
dev/
├── Project.toml       # Development dependencies
├── README.md         # This file
└── update_frontend.jl # Frontend artifact management
```
