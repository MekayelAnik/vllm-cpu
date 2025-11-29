FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    git \
    cmake \
    ninja-build \
    ccache \
    libnuma-dev \
    numactl \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# Set working directory
WORKDIR /build

# Copy build scripts and configuration
COPY build_wheels.sh .
COPY build_config.json .
COPY *.md .

# Set script as executable
RUN chmod +x build_wheels.sh

# Default command (can be overridden)
CMD ["./build_wheels.sh", "--help"]
