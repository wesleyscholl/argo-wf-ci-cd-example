#!/bin/bash
set -e

# Pre-warm Docker daemon
dockerd-entrypoint.sh &

# Wait for Docker to be ready
until docker info; do sleep 3; done

# Optional: Pre-pull common images or perform initialization
# docker pull some-image:tag

# Default command (can be overridden)
exec "$@"