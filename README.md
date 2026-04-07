<!-- markdownlint-disable MD001 MD041 -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/vllm-project/vllm/main/docs/assets/logos/vllm-logo-text-dark.png">
    <img alt="vLLM" src="https://raw.githubusercontent.com/vllm-project/vllm/main/docs/assets/logos/vllm-logo-text-light.png" width=55%>
  </picture>
</p>

<h3 align="center">
CPU-Optimized vLLM: Easy, Fast LLM Inference Without a GPU
</h3>

<p align="center">
  <strong>Unified CPU wheel with automatic ISA detection at runtime (AVX2, AVX-512, VNNI, BF16, AMX, NEON, FP16, DOTPROD)</strong>
</p>

<p align="center">
  <a href="https://pypi.org/project/vllm-cpu/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9&label=vllm-cpu" alt="PyPI Version">
  </a>
  <a href="https://pypi.org/project/vllm-cpu/">
    <img src="https://img.shields.io/pypi/dm/vllm-cpu?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9&label=Downloads" alt="PyPI Downloads">
  </a>
  <a href="https://pypi.org/project/vllm-cpu/">
    <img src="https://img.shields.io/pypi/pyversions/vllm-cpu?style=for-the-badge&logo=python&logoColor=white&labelColor=2b3137&color=3775a9" alt="Python Versions">
  </a>
</p>

<p align="center">
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/pulls/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=0db7ed" alt="Docker Pulls">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/stars/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=f0c14b" alt="Docker Stars">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/pkgs/container/vllm-cpu">
    <img src="https://img.shields.io/badge/GHCR-available-blue?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137" alt="GHCR">
  </a>
</p>

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
  <a href="https://github.com/MekayelAnik/vllm-cpu/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/MekayelAnik/vllm-cpu?style=for-the-badge&logo=gnu&logoColor=white&labelColor=2b3137&color=a32d2a" alt="License">
  </a>
</p>

<p align="center">
  <a href="https://github.com/MekayelAnik/vllm-cpu/commits/main">
    <img src="https://img.shields.io/github/last-commit/MekayelAnik/vllm-cpu?style=for-the-badge&logo=git&logoColor=white&labelColor=2b3137&color=ff6f00" alt="Last Commit">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=00bcd4" alt="Contributors">
  </a>
  <img src="https://img.shields.io/badge/platforms-x86__64%20%7C%20aarch64-green?style=for-the-badge&labelColor=2b3137" alt="Platforms">
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

## Why vllm-cpu?

The upstream vLLM project publishes CPU wheels only on GitHub Releases with a `+cpu` local version suffix, which **cannot be uploaded to PyPI**. Users must manually copy long URLs to install. This project solves that:

| Feature | Upstream (`vllm`) | This package (`vllm-cpu`) |
|---------|-------------------|---------------------------|
| Install | Manual URL from GitHub Releases | `pip install vllm-cpu` |
| PyPI | Not available (PEP 440 blocks `+cpu`) | Available |
| glibc | `manylinux_2_35` (Ubuntu 22.04+) | `manylinux_2_28` (Debian 10+, Ubuntu 18.04+) |
| Docker images | CUDA-only (`vllm/vllm-openai`) | CPU-optimized, multi-arch |
| ISA detection | Runtime auto-detect | Runtime auto-detect (same) |

## Quick Start

### Install from PyPI

```bash
pip install vllm-cpu
```

### Start an OpenAI-compatible API server

```python
from vllm import LLM, SamplingParams

llm = LLM(model="facebook/opt-125m", device="cpu")
output = llm.generate("The future of AI is", SamplingParams(temperature=0.8, max_tokens=128))
print(output[0].outputs[0].text)
```

### Or use the CLI

```bash
vllm serve facebook/opt-125m --device cpu --dtype auto
```

Then query it:

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "facebook/opt-125m", "prompt": "The future of AI is", "max_tokens": 128}'
```

## Requirements

- **Python**: 3.10+ (stable ABI, one wheel for all versions)
- **OS**: Linux (glibc 2.28+) — Debian 10+, Ubuntu 18.04+, RHEL 8+, Amazon Linux 2023+
- **CPU**: x86_64 with AVX2 (minimum) or AVX-512 (optimal), or aarch64 with NEON (BF16 recommended)

## Supported CPU Instructions

The unified wheel automatically detects and uses the best available instruction set:

| CPU Feature | Support | Detected At |
|-------------|---------|-------------|
| AVX2 | Baseline (all x86_64) | Import time |
| AVX512 | Optimal performance | Import time |
| AVX512-VNNI | INT8 acceleration | Import time |
| AVX512-BF16 | BFloat16 native ops | Import time |
| AMX-BF16 | Matrix acceleration (Sapphire Rapids+) | Import time |
| aarch64 NEON | ARM SIMD baseline | Import time |
| aarch64 FP16 | Half-precision float | Import time |
| aarch64 DOTPROD | INT8 dot product acceleration | Import time |
| aarch64 BF16 | Native BFloat16 (Graviton 3+, Ampere Altra+) | Import time |

No configuration needed — the correct `.so` is loaded automatically at `import vllm`.

## Install

### PyPI (recommended)

```bash
# Latest
pip install vllm-cpu

# Specific version
pip install vllm-cpu==0.18.0
```

### Docker

```bash
# GHCR (primary)
docker pull ghcr.io/mekayelanik/vllm-cpu:latest

# Docker Hub
docker pull mekayelanik/vllm-cpu:latest

# Specific version
docker pull ghcr.io/mekayelanik/vllm-cpu:0.18.0
```

## Docker Usage

### Quick start

```bash
docker run -d \
  --name vllm-cpu \
  -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  ghcr.io/mekayelanik/vllm-cpu:latest \
  --model facebook/opt-125m \
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
      - huggingface-cache:/root/.cache/huggingface
    command: ["--model", "facebook/opt-125m", "--dtype", "auto"]
    deploy:
      resources:
        limits:
          memory: 16g
    restart: unless-stopped

volumes:
  huggingface-cache:
```

## Available Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent stable release |
| `stable` | Promoted after 5 days as `latest` |
| `X.Y.Z` | Specific version (e.g., `0.17.0`) |
| `X.Y.Z-DDMMYYYY` | Version with build date |

## Supported Platforms

| Platform | Wheel | Docker |
|----------|-------|--------|
| x86_64 (amd64) | `manylinux_2_28_x86_64` | `linux/amd64` |
| aarch64 (arm64) | `manylinux_2_28_aarch64` | `linux/arm64` |

## How It Works

Starting with v0.17.0, vLLM ships a **unified CPU wheel** containing both AVX2 and AVX512 code paths:

1. The wheel includes `_C.so` (AVX512+BF16+VNNI+AMX) and `_C_AVX2.so` (AVX2 fallback)
2. At import time, `vllm/platforms/cpu.py` checks `torch._C._cpu._is_avx512_supported()`
3. The correct `.so` is loaded once — zero runtime dispatch overhead

### Stable ABI (cp38-abi3)

The wheels use Python's [stable ABI](https://docs.python.org/3/c-api/stable.html), meaning **one wheel works with Python 3.10+**. No per-Python-version builds needed.

### Build Process

Wheels are built from source inside `manylinux_2_28` containers with GCC 14, ensuring broad glibc compatibility while using modern compiler optimizations.

## Registries

| Registry | Image | URL |
|----------|-------|-----|
| PyPI | `vllm-cpu` | [pypi.org/project/vllm-cpu](https://pypi.org/project/vllm-cpu/) |
| GHCR | `ghcr.io/mekayelanik/vllm-cpu` | [GitHub Packages](https://github.com/MekayelAnik/vllm-cpu/pkgs/container/vllm-cpu) |
| Docker Hub | `mekayelanik/vllm-cpu` | [hub.docker.com](https://hub.docker.com/r/mekayelanik/vllm-cpu) |
| GitHub Releases | Wheel assets | [Releases](https://github.com/MekayelAnik/vllm-cpu/releases) |

## Version Support

| Version Range | Strategy | Status |
|---------------|----------|--------|
| v0.17.0+ | Unified CPU wheel | **Active** |
| v0.8.5 -- v0.15.x | Legacy 5-variant wheels | Archived on PyPI |

### Deprecated Variant Packages

The following variant packages have been **deprecated** as of v0.16.0 (last release). Starting with v0.17.0, the unified `vllm-cpu` package replaces all of them with automatic ISA detection at runtime.

| Package | Status | Migration |
|---------|--------|-----------|
| [`vllm-cpu-avx512`](https://pypi.org/project/vllm-cpu-avx512/) | Deprecated (last: v0.16.0) | `pip install vllm-cpu` |
| [`vllm-cpu-avx512vnni`](https://pypi.org/project/vllm-cpu-avx512vnni/) | Deprecated (last: v0.16.0) | `pip install vllm-cpu` |
| [`vllm-cpu-avx512bf16`](https://pypi.org/project/vllm-cpu-avx512bf16/) | Deprecated (last: v0.16.0) | `pip install vllm-cpu` |
| [`vllm-cpu-amxbf16`](https://pypi.org/project/vllm-cpu-amxbf16/) | Deprecated (last: v0.16.0) | `pip install vllm-cpu` |

These packages remain available on PyPI for older vLLM versions but will not receive further updates.

## Pipeline

```
Upstream vLLM release (v0.17.0+)
  --> Build unified CPU wheels in manylinux_2_28 (x86_64 + aarch64)
  --> Publish to PyPI + GitHub Releases
  --> Build multi-arch Docker images (linux/amd64 + linux/arm64)
  --> Push to GHCR + Docker Hub
  --> Promote :latest --> :stable (5-day soak)
```

## Links

- [vLLM Documentation](https://docs.vllm.ai/)
- [vLLM GitHub](https://github.com/vllm-project/vllm)
- [Report Issues](https://github.com/MekayelAnik/vllm-cpu/issues)
- [Changelog](https://github.com/MekayelAnik/vllm-cpu/releases)

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating/supporting my open-source projects.** If you found value in this project, you can buy me a coffee to keep me up all the sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="217" height="60">
</a>

</div>

---

## License

Same license as [vLLM](https://github.com/vllm-project/vllm/blob/main/LICENSE) (Apache 2.0).
