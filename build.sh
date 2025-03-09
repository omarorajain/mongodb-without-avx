#!/bin/bash

# Ensure at least one argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <mongo_version> [num_jobs]"
    exit 1
fi

# Assign arguments
MONGO_VERSION=$1
NUM_JOBS=${2:-1}  # Default to 1

image_name="${DOCKER_IMAGE:-omaj/mongodb-without-avx}"

# Build and push the image with specified version and num_jobs
docker buildx build \
    --platform linux/amd64 \
    --file Dockerfile \
    --build-arg MONGO_VERSION="$MONGO_VERSION" \
    --build-arg NUM_JOBS="$NUM_JOBS" \
    --tag "${image_name}:${MONGO_VERSION}" \
    --push .