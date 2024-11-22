"""
Extract frontend assets from the artifact to the assets directory.
Returns the path to the extracted assets.
"""
function setup_frontend_assets()
    # Path to Artifacts.toml in package root
    artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

    # Ensure the artifact is installed or download it otherwise
    ensure_artifact_installed("frontend", artifacts_toml)

    # Get the hash from Artifacts.toml
    frontend_hash = artifact_hash("frontend", artifacts_toml)
    if frontend_hash === nothing
        error("Frontend artifact not found. Please ensure Artifacts.toml is properly configured.")
    end

    # Get path to the downloaded artifact
    artifact_dir = artifact_path(frontend_hash)

    # Find the dist directory in the release structure
    release_dir = only(readdir(artifact_dir))
    dist_dir = joinpath(artifact_dir, release_dir)

    # Create/clean assets directory
    assets_dir = joinpath(@__DIR__, "..", "assets")
    rm(assets_dir, force = true, recursive = true)
    mkpath(assets_dir)

    # Copy all files from dist to assets
    for file in readdir(dist_dir)
        cp(joinpath(dist_dir, file), joinpath(assets_dir, file))
    end

    return assets_dir
end
