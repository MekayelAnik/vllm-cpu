<!-- markdownlint-disable MD001 MD041 -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/vllm-project/vllm/main/docs/assets/logos/vllm-logo-text-dark.png">
    <img alt="vLLM" src="https://raw.githubusercontent.com/vllm-project/vllm/main/docs/assets/logos/vllm-logo-text-light.png" width=55%>
  </picture>
</p>

<h3 align="center">
Easy, fast, and cheap LLM serving for everyone
</h3>

<h4 align="center">
Docker Images for CPU-Only Inference
</h4>

<p align="center">
  <a href="https://github.com/MekayelAnik/vllm-cpu/stargazers">
    <img src="https://img.shields.io/github/stars/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=f0c14b" alt="GitHub Stars">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/network/members">
    <img src="https://img.shields.io/github/forks/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=6cc644" alt="GitHub Forks">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/issues">
    <img src="https://img.shields.io/github/issues/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=d73a49" alt="GitHub Issues">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/pulls">
    <img src="https://img.shields.io/github/issues-pr/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=2188ff" alt="GitHub PRs">
  </a>
</p>

<p align="center">
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/pulls/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=0db7ed" alt="Docker Pulls">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/stars/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=f0c14b" alt="Docker Stars">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/v/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=6cc644&label=version" alt="Docker Version">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/image-size/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=9c27b0" alt="Docker Image Size">
  </a>
</p>

<p align="center">
  <a href="https://github.com/MekayelAnik/vllm-cpu/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/MekayelAnik/vllm-cpu?style=for-the-badge&logo=gnu&logoColor=white&labelColor=2b3137&color=a32d2a" alt="License">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/commits/main">
    <img src="https://img.shields.io/github/last-commit/MekayelAnik/vllm-cpu?style=for-the-badge&logo=git&logoColor=white&labelColor=2b3137&color=ff6f00" alt="Last Commit">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=00bcd4" alt="Contributors">
  </a>
</p>

<p align="center">
<b><a href="https://docs.vllm.ai/en/latest/">Documentation</a></b> | <b><a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">Docker Hub</a></b> | <b><a href="https://github.com/MekayelAnik/vllm-cpu">GitHub</a></b> | <b><a href="https://docs.vllm.ai/en/latest/models/supported_models.html">Supported Models</a></b>
</p>

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating/supporting my open-source projects.** If you found value in this project, you can buy me a coffee to keep me up all the sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="217" height="60">
</a>

</div>

---

## Table of Contents

- [Overview](#overview)
- [Image Variants](#image-variants)
- [Quick Start](#quick-start)
- [Docker Compose Examples](#docker-compose-examples)
  - [Standard Bridge Network](#standard-bridge-network-recommended)
  - [MACVLAN Network](#macvlan-network-advanced)
  - [High Performance Production](#high-performance-production-server)
- [Environment Variables](#environment-variables)
- [Volume Mounts](#volume-mounts)
- [Runtime Configuration](#runtime-configuration)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)
- [Updating Images](#updating-images)
- [Support & License](#support--license)

---

## Overview

This repository provides pre-built Docker images for running vLLM on CPU-only systems. These images are optimized for different CPU instruction sets, allowing you to choose the best variant for your hardware.

### Key Features

- **OpenAI-Compatible API** - Drop-in replacement for OpenAI API endpoints
- **Multiple CPU Optimizations** - AVX512, VNNI, BF16, and AMX variants available
- **Multi-Architecture Support** - x86_64 and ARM64 (noavx512 variant only)
- **Minimal Runtime** - Based on Debian slim for reduced image size
- **Health Checks** - Built-in health endpoint for container orchestration
- **Flexible Configuration** - Extensive environment variable support
- **User Mapping** - PUID/PGID support for proper file permissions

### System Requirements

| Resource | Minimum | Recommended |
|:---------|:--------|:------------|
| **RAM** | 4 GB | 16+ GB |
| **CPU Cores** | 4 | 8+ |
| **Storage** | 10 GB | 50+ GB (for models) |
| **Docker** | 20.10+ | 24.0+ |
| **Shared Memory** | 2 GB | 4+ GB |

---

## Image Variants

Choose the appropriate variant based on your CPU's instruction set support:

| Variant | Tag | Optimizations | Target CPUs | Architectures |
|:--------|:----|:--------------|:------------|:--------------|
| **noavx512** | `noavx512-<version>` | Baseline | All CPUs | x86_64, ARM64 |
| **avx512** | `avx512-<version>` | AVX512 | Intel Skylake-X+ | x86_64 |
| **avx512vnni** | `avx512vnni-<version>` | AVX512 + VNNI | Intel Cascade Lake+ | x86_64 |
| **avx512bf16** | `avx512bf16-<version>` | AVX512 + VNNI + BF16 | Intel Cooper Lake+ | x86_64 |
| **amxbf16** | `amxbf16-<version>` | AVX512 + VNNI + BF16 + AMX | Intel Sapphire Rapids+ | x86_64 |

### Available Tags

Each variant has two tag formats:
- **Version-specific**: `<variant>-<version>` (e.g., `avx512bf16-0.12.0`)
- **Latest**: `<variant>-latest` (e.g., `avx512bf16-latest`)

### Check Your CPU Support

```bash
# Check available instruction sets
lscpu | grep -E "avx512|vnni|amx"

# Or use flags
grep -o 'avx512[a-z_]*\|amx[a-z_]*' /proc/cpuinfo | sort -u
```

---

## Quick Start

### Docker CLI

```bash
# Pull the image
docker pull mekayelanik/vllm-cpu:noavx512-latest

# Run with a small model
docker run -d \
  --name vllm-cpu \
  --restart unless-stopped \
  --cap-add SYS_NICE \
  --security-opt seccomp=unconfined \
  --shm-size 4g \
  -p 8000:8000 \
  -v vllm-data:/data \
  -e VLLM_MODEL=Qwen/Qwen3-0.6B \
  -e VLLM_SERVER_HOST=0.0.0.0 \
  -e VLLM_SERVER_PORT=8000 \
  mekayelanik/vllm-cpu:noavx512-latest \
  --max-model-len 8192

# Check logs
docker logs -f vllm-cpu

# Test the API
curl http://localhost:8000/v1/models
```

### API Endpoints

| Endpoint | Description |
|:---------|:------------|
| `/health` | Health check endpoint |
| `/v1/models` | List available models |
| `/v1/completions` | Text completions API |
| `/v1/chat/completions` | Chat completions API |
| `/v1/embeddings` | Embeddings API |

---

## Docker Compose Examples

### Standard Bridge Network (Recommended)

This is the simplest and most portable configuration, suitable for most deployments.

```yaml
# docker-compose.yml - Standard Bridge Network
# Save this file and run: docker compose up -d

services:
  vllm-cpu:
    image: mekayelanik/vllm-cpu:noavx512-latest
    container_name: vllm-cpu
    hostname: vllm-cpu
    domainname: local
    restart: unless-stopped

    # Required capabilities for CPU optimization
    cap_add:
      - SYS_NICE
    security_opt:
      - seccomp=unconfined

    # Shared memory for model loading
    shm_size: 4g

    # Port mapping
    ports:
      - "8000:8000"

    # Persistent storage
    volumes:
      - vllm-data:/data
      - vllm-cache:/data/cache
      # Optional: Mount local HuggingFace cache
      # - ${HOME}/.cache/huggingface:/data/models

    # Environment configuration
    environment:
      # User/Group mapping (optional)
      - PUID=1000
      - PGID=1000
      - TZ=UTC

      # Model configuration
      - VLLM_MODEL=Qwen/Qwen3-0.6B
      # - HF_TOKEN=your_huggingface_token  # For gated models

      # Server configuration
      - VLLM_SERVER_HOST=0.0.0.0
      - VLLM_SERVER_PORT=8000
      # - VLLM_API_KEY=your_api_key  # Optional API key

      # Logging
      - VLLM_LOGGING_LEVEL=INFO
      - VLLM_CONFIGURE_LOGGING=1

      # Memory optimization
      - MALLOC_TRIM_THRESHOLD_=100000

    # vLLM arguments (passed to entrypoint)
    command:
      - "--max-model-len"
      - "8192"
      - "--dtype"
      - "auto"

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      start_period: 120s
      retries: 3

    # Resource limits (optional)
    deploy:
      resources:
        limits:
          memory: 16G
        reservations:
          memory: 4G

# Named volumes for persistence
volumes:
  vllm-data:
    driver: local
  vllm-cache:
    driver: local
```

**Deploy:**
```bash
# Start the service
docker compose up -d

# View logs
docker compose logs -f vllm-cpu

# Check status
docker compose ps

# Stop the service
docker compose down
```

---

### MACVLAN Network (Advanced)

MACVLAN gives the container its own IP address on your local network, making it appear as a separate physical device. This is useful for:
- Direct LAN access without port forwarding
- Running multiple vLLM instances with unique IPs
- Integration with network services that require dedicated IPs

**Prerequisites:**
- Linux host (MACVLAN doesn't work on Docker Desktop for Mac/Windows)
- Know your network interface name (e.g., `eth0`, `ens18`, `enp0s3`)
- Available IP address in your network range
- Promiscuous mode enabled on network interface (for some setups)

```yaml
# docker-compose-macvlan.yml - MACVLAN Network Configuration
# Save this file and run: docker compose -f docker-compose-macvlan.yml up -d

services:
  vllm-cpu:
    image: mekayelanik/vllm-cpu:avx512bf16-latest
    container_name: vllm-cpu
    hostname: vllm-cpu
    domainname: local
    restart: unless-stopped

    # Required capabilities
    cap_add:
      - SYS_NICE
    security_opt:
      - seccomp=unconfined

    # Shared memory
    shm_size: 4g

    # MAC address (generate unique one for your network)
    mac_address: "02:42:c0:a8:01:64"

    # MACVLAN network with static IP
    networks:
      vllm-macvlan:
        ipv4_address: 192.168.1.100

    # Persistent storage
    volumes:
      - vllm-data:/data
      - vllm-cache:/data/cache
      # Mount local models directory
      - /path/to/models:/data/models:ro

    # Environment configuration
    environment:
      # User/Group mapping
      - PUID=1000
      - PGID=1000
      - TZ=UTC

      # Model configuration
      - VLLM_MODEL=Qwen/Qwen3-0.6B
      - HF_HOME=/data/models
      # - HF_TOKEN=your_huggingface_token

      # Server configuration (bind to all interfaces)
      - VLLM_SERVER_HOST=0.0.0.0
      - VLLM_SERVER_PORT=8000

      # Logging
      - VLLM_LOGGING_LEVEL=INFO
      - VLLM_CONFIGURE_LOGGING=1

      # Performance tuning
      - MALLOC_TRIM_THRESHOLD_=100000
      - OMP_NUM_THREADS=8
      - MKL_NUM_THREADS=8

    # vLLM arguments
    command:
      - "--max-model-len"
      - "16384"
      - "--dtype"
      - "bfloat16"
      - "--cpu-offload-gb"
      - "0"

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      start_period: 180s
      retries: 3

    # Resource limits
    deploy:
      resources:
        limits:
          memory: 32G
        reservations:
          memory: 8G

# MACVLAN Network Definition
networks:
  vllm-macvlan:
    driver: macvlan
    driver_opts:
      # Change to your network interface name
      parent: eth0
    ipam:
      driver: default
      config:
        # Adjust to match your network configuration
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.1
          # IP range for containers (optional, limits assignable IPs)
          ip_range: 192.168.1.100/30

# Named volumes
volumes:
  vllm-data:
    driver: local
  vllm-cache:
    driver: local
```

**Find Your Network Interface:**
```bash
# List network interfaces
ip link show

# Or use
ip addr show

# Common interface names:
# - eth0, eth1 (traditional)
# - ens18, ens192 (predictable naming)
# - enp0s3, enp0s8 (PCI-based naming)
```

**Deploy with MACVLAN:**
```bash
# Create and start
docker compose -f docker-compose-macvlan.yml up -d

# Access via dedicated IP
curl http://192.168.1.100:8000/v1/models

# View logs
docker compose -f docker-compose-macvlan.yml logs -f

# Stop
docker compose -f docker-compose-macvlan.yml down
```

**Host-to-Container Communication:**

With MACVLAN, the host cannot directly communicate with the container. To enable this, create a macvlan interface on the host:

```bash
# Create macvlan interface on host
sudo ip link add vllm-shim link eth0 type macvlan mode bridge
sudo ip addr add 192.168.1.200/32 dev vllm-shim
sudo ip link set vllm-shim up
sudo ip route add 192.168.1.100/32 dev vllm-shim

# Now host can reach container
curl http://192.168.1.100:8000/health
```

---

### High Performance Production Server

This configuration is optimized for **high-load, high-concurrency production environments** with maximum throughput. Designed for enterprise deployments on high-end Intel Xeon or AMD EPYC servers.

**Target Hardware:**
- 32+ CPU cores (64+ threads)
- 128+ GB RAM
- NVMe storage for model files
- 10GbE+ networking

**Use Cases:**
- Production API serving with hundreds of concurrent users
- High-throughput batch processing
- Enterprise LLM deployments
- Multi-tenant inference services

```yaml
# docker-compose-high-performance.yml - High Load Production Configuration
# Optimized for maximum throughput and concurrency
# Run: docker compose -f docker-compose-high-performance.yml up -d

services:
  vllm-cpu-prod:
    image: mekayelanik/vllm-cpu:amxbf16-latest
    container_name: vllm-cpu-prod
    hostname: vllm-prod
    domainname: local
    restart: always

    # Use host network for maximum network performance
    network_mode: host

    # Extended capabilities for performance optimization
    cap_add:
      - SYS_NICE
      - IPC_LOCK
    security_opt:
      - seccomp=unconfined

    # Large shared memory for concurrent request handling
    shm_size: 16g

    # CPU pinning for NUMA optimization (adjust to your topology)
    # cpuset: "0-31"

    # Persistent storage with performance optimizations
    volumes:
      # Use fast NVMe storage for models
      - /mnt/nvme/vllm-data:/data
      - /mnt/nvme/vllm-cache:/data/cache
      - /mnt/nvme/models:/data/models:ro
      # tmpfs for temporary files
      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 4G
          mode: 1777

    # Production environment configuration
    environment:
      # Run as root for maximum performance (or set specific user)
      # - PUID=0
      # - PGID=0
      - TZ=UTC

      # Model configuration - use a powerful model
      - VLLM_MODEL=Qwen/Qwen3-8B
      - HF_HOME=/data/models
      - HF_HUB_OFFLINE=1
      # - HF_TOKEN=your_token

      # Server configuration
      - VLLM_SERVER_HOST=0.0.0.0
      - VLLM_SERVER_PORT=8000
      - VLLM_API_KEY=${VLLM_API_KEY:-}

      # Extended timeouts for high load
      - VLLM_HTTP_TIMEOUT_KEEP_ALIVE=30
      - VLLM_ENGINE_ITERATION_TIMEOUT_S=300
      - VLLM_RPC_TIMEOUT=30000

      # Logging - reduce verbosity for performance
      - VLLM_CONFIGURE_LOGGING=1
      - VLLM_LOGGING_LEVEL=WARNING
      - VLLM_LOG_STATS_INTERVAL=60

      # Memory optimization - aggressive settings
      - MALLOC_TRIM_THRESHOLD_=65536
      - MALLOC_MMAP_THRESHOLD_=131072
      - MALLOC_MMAP_MAX_=65536

      # Threading - set to physical core count
      - OMP_NUM_THREADS=32
      - MKL_NUM_THREADS=32
      - OMP_PROC_BIND=close
      - OMP_PLACES=cores

      # NUMA optimization
      - GOMP_CPU_AFFINITY=0-31
      - KMP_AFFINITY=granularity=fine,compact,1,0
      - KMP_BLOCKTIME=1

      # Use tcmalloc for better memory performance
      - LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4

      # Disable usage stats for privacy/performance
      - VLLM_NO_USAGE_STATS=1
      - VLLM_DO_NOT_TRACK=1

    # High-performance vLLM arguments
    command:
      # Context length
      - "--max-model-len"
      - "32768"
      # Data type for Intel AMX
      - "--dtype"
      - "bfloat16"
      # Scheduling for high concurrency
      - "--max-num-seqs"
      - "256"
      - "--max-num-batched-tokens"
      - "32768"
      # Disable request logging for performance
      - "--disable-log-requests"
      # Enable chunked prefill for better latency
      - "--enable-chunked-prefill"
      - "--max-chunked-prefill-len"
      - "8192"
      # Speculative decoding (if supported by model)
      # - "--speculative-model"
      # - "path/to/draft/model"
      # - "--num-speculative-tokens"
      # - "5"

    # Aggressive health check
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8000/health"]
      interval: 15s
      timeout: 5s
      start_period: 300s
      retries: 5

    # No resource limits - use all available resources
    # deploy:
    #   resources:
    #     limits:
    #       memory: 120G
    #     reservations:
    #       memory: 64G

    # Logging configuration
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"
        compress: "true"

    # Ulimits for high concurrency
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 1048576
        hard: 1048576
      nproc:
        soft: 65535
        hard: 65535
```

**Pre-Deployment Checklist:**

```bash
# 1. Verify CPU supports AMX (for amxbf16 variant)
lscpu | grep -i amx

# 2. Check available memory
free -h

# 3. Verify NUMA topology
numactl --hardware

# 4. Pre-download models (for offline mode)
docker run --rm -v /mnt/nvme/models:/models \
  python:3.12-slim pip install huggingface_hub && \
  python -c "from huggingface_hub import snapshot_download; \
  snapshot_download('Qwen/Qwen3-8B', local_dir='/models/Qwen--Qwen3-8B')"

# 5. Set kernel parameters for high performance
sudo sysctl -w vm.swappiness=1
sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535
```

**Deploy High Performance:**
```bash
# Start production server
docker compose -f docker-compose-high-performance.yml up -d

# Monitor performance
docker stats vllm-cpu-prod

# Watch logs
docker compose -f docker-compose-high-performance.yml logs -f

# Benchmark with concurrent requests
for i in {1..100}; do
  curl -s http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"Qwen/Qwen3-8B","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}' &
done
wait
```

**Monitoring & Observability:**

```yaml
# Add Prometheus metrics endpoint
command:
  - "--enable-metrics"
  - "--metrics-port"
  - "9090"

# Prometheus scrape config
# scrape_configs:
#   - job_name: 'vllm'
#     static_configs:
#       - targets: ['localhost:9090']
```

---

## Environment Variables

### Core Settings

| Variable | Default | Description |
|:---------|:--------|:------------|
| `PUID` | (unset) | User ID for running vLLM |
| `PGID` | (unset) | Group ID for running vLLM |
| `TZ` | `UTC` | Timezone |
| `DATA_DIR` | `/data` | Base data directory |

### Model Configuration

| Variable | Default | Description |
|:---------|:--------|:------------|
| `VLLM_MODEL` | (required) | HuggingFace model ID or local path |
| `VLLM_TOKENIZER` | (empty) | Custom tokenizer (if different from model) |
| `HF_TOKEN` | (empty) | HuggingFace access token for gated models |
| `HF_HOME` | `/data/models` | HuggingFace cache directory |
| `HF_HUB_OFFLINE` | (empty) | Set to `1` for offline mode |

### Server Configuration

| Variable | Default | Description |
|:---------|:--------|:------------|
| `VLLM_SERVER_HOST` | `0.0.0.0` | Server bind address |
| `VLLM_SERVER_PORT` | `8000` | Server port |
| `VLLM_API_KEY` | (empty) | API key for authentication |
| `VLLM_HTTP_TIMEOUT_KEEP_ALIVE` | `5` | HTTP keep-alive timeout (seconds) |

### Logging

| Variable | Default | Description |
|:---------|:--------|:------------|
| `VLLM_CONFIGURE_LOGGING` | `1` | Enable logging configuration |
| `VLLM_LOGGING_LEVEL` | `INFO` | Log level (DEBUG, INFO, WARNING, ERROR) |

### Performance

| Variable | Default | Description |
|:---------|:--------|:------------|
| `MALLOC_TRIM_THRESHOLD_` | `100000` | Memory trim threshold |
| `OMP_NUM_THREADS` | (auto) | OpenMP thread count |
| `MKL_NUM_THREADS` | (auto) | MKL thread count |

---

## Volume Mounts

| Container Path | Purpose | Recommended |
|:---------------|:--------|:------------|
| `/data` | Base data directory | Named volume |
| `/data/models` | HuggingFace cache | Named volume or host mount |
| `/data/cache/vllm` | vLLM cache | Named volume |

### Example with Host Mounts

```yaml
volumes:
  # Use existing HuggingFace cache
  - ${HOME}/.cache/huggingface:/data/models
  # Persist vLLM cache
  - ./vllm-cache:/data/cache/vllm
  # Mount local models (read-only)
  - /mnt/models:/models:ro
```

---

## Runtime Configuration

Pass additional vLLM arguments via the `command` section:

```yaml
command:
  - "--max-model-len"
  - "8192"
  - "--dtype"
  - "auto"
  - "--enforce-eager"
  - "--disable-log-requests"
```

### Common Arguments

| Argument | Description | Example |
|:---------|:------------|:--------|
| `--max-model-len` | Maximum context length | `8192` |
| `--dtype` | Data type (auto, float16, bfloat16, float32) | `auto` |
| `--enforce-eager` | Disable CUDA graphs (use for debugging) | (flag) |
| `--disable-log-requests` | Don't log individual requests | (flag) |
| `--cpu-offload-gb` | CPU memory for offloading (GB) | `0` |
| `--trust-remote-code` | Allow remote code execution | (flag) |

---

## Performance Tuning

### Memory Optimization

```yaml
environment:
  # Aggressive memory trimming
  - MALLOC_TRIM_THRESHOLD_=100000

  # Limit context length to reduce memory
command:
  - "--max-model-len"
  - "4096"
```

### CPU Threading

```yaml
environment:
  # Match to your physical core count
  - OMP_NUM_THREADS=8
  - MKL_NUM_THREADS=8
```

### Shared Memory

```yaml
# Increase for larger models
shm_size: 8g
```

### Docker Resource Limits

```yaml
deploy:
  resources:
    limits:
      memory: 32G
      cpus: '8'
    reservations:
      memory: 8G
      cpus: '4'
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs vllm-cpu

# Verify image pulled correctly
docker images | grep vllm-cpu

# Test with minimal config
docker run --rm mekayelanik/vllm-cpu:noavx512-latest --help
```

### Out of Memory Errors

1. Reduce `--max-model-len` to lower context length
2. Use a smaller model
3. Increase Docker memory limits
4. Increase `shm_size`

```yaml
command:
  - "--max-model-len"
  - "2048"  # Reduce from default
```

### Model Download Fails

```bash
# Check HuggingFace token for gated models
docker exec vllm-cpu env | grep HF_TOKEN

# Verify network connectivity
docker exec vllm-cpu curl -I https://huggingface.co

# Use offline mode with pre-downloaded models
environment:
  - HF_HUB_OFFLINE=1
```

### Slow Inference

1. Verify you're using the correct CPU variant for your hardware
2. Check CPU frequency scaling
3. Ensure adequate cooling (thermal throttling)

```bash
# Check CPU frequency
cat /proc/cpuinfo | grep MHz

# Monitor container resources
docker stats vllm-cpu
```

### Health Check Failing

Increase `start_period` for larger models:

```yaml
healthcheck:
  start_period: 300s  # 5 minutes for large models
```

---

## Updating Images

### Docker Compose

```bash
# Pull latest image
docker compose pull

# Recreate container
docker compose up -d

# Clean old images
docker image prune -f
```

### Docker CLI

```bash
# Pull new image
docker pull mekayelanik/vllm-cpu:noavx512-latest

# Stop and remove old container
docker stop vllm-cpu && docker rm vllm-cpu

# Start with new image
docker run -d --name vllm-cpu ... mekayelanik/vllm-cpu:noavx512-latest

# Clean up
docker image prune -f
```

### Automated Updates with Watchtower

```bash
# One-time update
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once \
  vllm-cpu
```

---

## Support & License

### Getting Help

- **Docker Image Issues:** [GitHub Issues](https://github.com/MekayelAnik/vllm-cpu/issues)
- **vLLM Documentation:** [docs.vllm.ai](https://docs.vllm.ai/en/latest/)
- **Supported Models:** [Model List](https://docs.vllm.ai/en/latest/models/supported_models.html)

### License

- **Docker Images:** GPL-3.0 License
- **vLLM Project:** Apache 2.0 License

### Image Repositories

- **Docker Hub:** [mekayelanik/vllm-cpu](https://hub.docker.com/r/mekayelanik/vllm-cpu)
- **GitHub Container Registry:** [ghcr.io/mekayelanik/vllm-cpu](https://ghcr.io/mekayelanik/vllm-cpu)

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating/supporting my open-source projects.** If you found value in this project, you can buy me a coffee to keep me up all the sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="217" height="60">
</a>

</div>

---

<div align="center">

[Back to Top](#table-of-contents)

</div>
