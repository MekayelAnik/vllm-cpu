# vllm-cpu

Unified CPU wheels and Docker images for [vLLM](https://github.com/vllm-project/vllm) — the fast and easy-to-use library for LLM inference and serving.

## What this provides

**What upstream doesn't:**
- **PyPI package** — `pip install vllm-cpu` (upstream CPU wheels can't be uploaded to PyPI due to `+cpu` local version suffix)
- **Docker images** — Pre-configured with CPU optimizations (tcmalloc, OMP, NUMA)
- **Broader glibc support** — Built with `manylinux_2_28` (glibc 2.28+, Debian 10+/Ubuntu 18.04+) vs upstream's `manylinux_2_35`
- **Simple install** — No need to copy long GitHub release URLs

## Install

### PyPI (wheel)

```bash
pip install vllm-cpu
```

### Docker

```bash
# GHCR (primary)
docker pull ghcr.io/mekayelanik/vllm-cpu:latest

# Docker Hub
docker pull mekayelanik/vllm-cpu:latest
```

### Specific version

```bash
pip install vllm-cpu==0.17.0

docker pull ghcr.io/mekayelanik/vllm-cpu:0.17.0
```

## Available Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent stable release |
| `stable` | Promoted after 5 days as `latest` |
| `X.Y.Z` | Specific version (e.g., `0.17.0`) |

## Supported Platforms

| Platform | Wheel | Docker |
|----------|-------|--------|
| x86_64 (amd64) | `manylinux_2_28_x86_64` | `linux/amd64` |
| aarch64 (arm64) | `manylinux_2_28_aarch64` | `linux/arm64` |

## How it works

Starting with v0.17.0, vLLM ships a **unified CPU wheel** containing both AVX2 and AVX512 code:
- The wheel includes `_C.so` (AVX512+BF16+VNNI+AMX) and `_C_AVX2.so` (AVX2 fallback)
- At import time, vLLM detects CPU capabilities and loads the correct binary
- Zero runtime dispatch overhead — the right `.so` is loaded once at startup

### Stable ABI (cp38-abi3)

The wheels use Python's [stable ABI](https://docs.python.org/3/c-api/stable.html), meaning **one wheel works with Python 3.8+**. No need for separate per-Python-version builds.

## Docker Usage

### Quick start

```bash
docker run -d \
  --name vllm-cpu \
  -p 8000:8000 \
  ghcr.io/mekayelanik/vllm-cpu:latest \
  --model <your-model> \
  --dtype auto
```

### Docker Compose

```yaml
services:
  vllm:
    image: ghcr.io/mekayelanik/vllm-cpu:latest
    ports:
      - "8000:8000"
    volumes:
      - ./models:/root/.cache/huggingface
    command: ["--model", "<your-model>", "--dtype", "auto"]
    deploy:
      resources:
        limits:
          memory: 16g
```

## Registries

| Registry | Image |
|----------|-------|
| GHCR (primary) | `ghcr.io/mekayelanik/vllm-cpu` |
| Docker Hub | `mekayelanik/vllm-cpu` |

## Version Support

| Version Range | Strategy | Status |
|---------------|----------|--------|
| v0.17.0+ | Unified CPU wheel (this repo) | Active |
| v0.8.5–v0.15.x | Legacy 5-variant wheels | Archived on PyPI |

## Pipeline

```
Upstream vLLM release detected
  → Build wheels from source in manylinux_2_28 (x86_64 + aarch64)
  → Publish to PyPI + GitHub Releases
  → Build multi-arch Docker images
  → Push to GHCR + Docker Hub
  → Promote :latest → :stable (5-day soak)
```

## License

Same license as [vLLM](https://github.com/vllm-project/vllm/blob/main/LICENSE).
