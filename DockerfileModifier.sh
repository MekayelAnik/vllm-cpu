#!/bin/bash
# =============================================================================
# DockerfileModifier.sh — Generate Dockerfile for vLLM CPU Docker image
# =============================================================================
# Reads build data from resources/build_data/ and generates a Dockerfile
# by templating docker/Dockerfile with the correct build args.
#
# Called by reusable-build-versions.yml during Docker image builds.
# =============================================================================

set -ex

REPO_NAME='vllm-cpu'
DOCKERFILE_NAME="Dockerfile.$REPO_NAME"

# Check for required build data
if [ ! -e ./resources/build_data/base-image ] || [ ! -e ./resources/build_data/version ]; then
    echo "Could not find required build data files. Exiting..."
    exit 1
fi

BASE_IMAGE=$(cat ./resources/build_data/base-image)
VLLM_VERSION=$(cat ./resources/build_data/version)

# Use docker/Dockerfile as template, substitute default build args
if [ -f ./docker/Dockerfile ]; then
    sed \
        -e "s|^ARG BASE_IMAGE=.*|ARG BASE_IMAGE=${BASE_IMAGE}|" \
        -e "s|^ARG VLLM_VERSION\$|ARG VLLM_VERSION=${VLLM_VERSION}|" \
        -e "s|^ARG VLLM_VERSION=.*|ARG VLLM_VERSION=${VLLM_VERSION}|" \
        ./docker/Dockerfile > "$DOCKERFILE_NAME"
else
    echo "Error: docker/Dockerfile not found" >&2
    exit 1
fi

echo "Dockerfile generation completed!"
echo "  Base image: $BASE_IMAGE"
echo "  vLLM version: $VLLM_VERSION"
echo "######      DOCKERFILE START     ######"
cat "$DOCKERFILE_NAME"
echo "######      DOCKERFILE END     ######"
