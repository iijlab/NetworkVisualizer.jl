#!/usr/bin/env julia

using SHA
using Tar
using Downloads
using CodecZlib
using Pkg.Artifacts

# Remove 'v' prefix if provided
version = length(ARGS) == 1 ? ARGS[1] : error("Usage: julia update_frontend.jl VERSION")
version_num = startswith(version, 'v') ? version[2:end] : version
version_tag = "v$(version_num)"

url = "https://github.com/iijlab/NetworkVisualizer.js/archive/refs/tags/$version_tag.tar.gz"

# Download the release first to get its hash
@info "Downloading release from $url"
tarball = Downloads.download(url)
sha256_hash = bytes2hex(open(sha256, tarball))

# Create a new artifact and populate it
frontend_hash = create_artifact() do artifact_dir
    # Extract the contents
    compressed = read(tarball)
    decompressed = transcode(GzipDecompressor, compressed)
    Tar.extract(IOBuffer(decompressed), artifact_dir)
end

# Clean up
rm(tarball)

# Create or update Artifacts.toml
artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

@info "Writing to $artifacts_toml"
bind_artifact!(artifacts_toml, "frontend", frontend_hash;
    download_info = [(url, sha256_hash)],
    force = true,
)

@info "Successfully created and bound frontend artifact"
