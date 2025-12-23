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
  <strong>5 PyPI packages optimized for different Intel/AMD CPU instruction sets</strong>
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
  <a href="https://pypi.org/project/vllm-cpu/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9&label=vllm-cpu" alt="vllm-cpu">
  </a>
  <a href="https://pypi.org/project/vllm-cpu-avx512/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu-avx512?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9&label=avx512" alt="vllm-cpu-avx512">
  </a>
  <a href="https://pypi.org/project/vllm-cpu-avx512vnni/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu-avx512vnni?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9&label=vnni" alt="vllm-cpu-avx512vnni">
  </a>
  <a href="https://pypi.org/project/vllm-cpu-avx512bf16/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu-avx512bf16?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9&label=bf16" alt="vllm-cpu-avx512bf16">
  </a>
  <a href="https://pypi.org/project/vllm-cpu-amxbf16/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu-amxbf16?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9&label=amx" alt="vllm-cpu-amxbf16">
  </a>
</p>

<p align="center">
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/pulls/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=0db7ed" alt="Docker Pulls">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/v/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=6cc644&label=docker" alt="Docker Version">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/image-size/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=9c27b0" alt="Docker Image Size">
  </a>
</p>

<p align="center">
  <a href="https://github.com/MekayelAnik/vllm-cpu/commits/main">
    <img src="https://img.shields.io/github/last-commit/MekayelAnik/vllm-cpu?style=for-the-badge&logo=git&logoColor=white&labelColor=2b3137&color=ff6f00" alt="Last Commit">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=00bcd4" alt="Contributors">
  </a>
</p>

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating and maintaining open-source projects.**
If you found value in this project, consider buying me a coffee to fuel those sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="217" height="60">
</a>

</div>

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Package Variants](#package-variants)
- [Which Package Should I Use?](#which-package-should-i-use)
- [Installation](#installation)
- [Docker Deployment](#docker-deployment)
- [Usage Examples](#usage-examples)
- [CPU Compatibility Guide](#cpu-compatibility-guide)
- [Performance Tips](#performance-tips)
- [Troubleshooting](#troubleshooting)
- [Links & Resources](#links--resources)

---

## Overview

This project provides **5 CPU-optimized PyPI packages** built from the upstream [vLLM](https://github.com/vllm-project/vllm) source code. Each package is compiled with specific Intel/AMD CPU instruction set flags to maximize inference performance on different CPU generations.

**Why CPU inference?**
- No expensive GPU required
- Run LLMs on any server, laptop, or edge device
- Lower power consumption and operational costs
- Ideal for development, testing, and moderate-scale deployments
- ARM64 support for AWS Graviton, Apple Silicon, and Raspberry Pi

**Key Features:**
- State-of-the-art serving throughput with PagedAttention
- Continuous batching for high concurrency
- OpenAI-compatible API server
- Support for 100+ popular models (Llama, Mistral, Qwen, etc.)
- Quantization support: GPTQ, AWQ, INT4, INT8, FP8
- Multi-LoRA serving
- Streaming outputs

---

## Quick Start

### 1. Detect Your CPU's Optimal Package

```bash
# Detect CPU features and get install command
pkg=vllm-cpu
grep -q avx512f /proc/cpuinfo && pkg=vllm-cpu-avx512
grep -q avx512_vnni /proc/cpuinfo && pkg=vllm-cpu-avx512vnni
grep -q avx512_bf16 /proc/cpuinfo && pkg=vllm-cpu-avx512bf16
grep -q amx_bf16 /proc/cpuinfo && pkg=vllm-cpu-amxbf16
printf "\n\tRUN:\n\t\tuv pip install $pkg\n"
```

### 2. Install the Right Package

```bash
# For most modern Intel/AMD CPUs (baseline, works everywhere)
pip install vllm-cpu --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple

# For Intel Sapphire Rapids / 4th Gen Xeon (best performance)
pip install vllm-cpu-amxbf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

### 3. Run Your First Model

```python
from vllm import LLM, SamplingParams

llm = LLM(model="facebook/opt-125m", device="cpu")
outputs = llm.generate(["Hello, my name is"], SamplingParams(max_tokens=50))
print(outputs[0].outputs[0].text)
```

### 4. Or Use Docker (Zero Setup)

```bash
docker run -p 8000:8000 mekayelanik/vllm-cpu:noavx512-latest --model facebook/opt-125m
```

---

## Package Variants

| Package | Instruction Sets | Target CPUs | Platforms | PyPI |
|---------|-----------------|-------------|-----------|------|
| **vllm-cpu** | Baseline (no AVX512) | All x86_64 + ARM64 | `linux/amd64`, `linux/arm64` | [![PyPI](https://img.shields.io/pypi/v/vllm-cpu?logo=pypi&logoColor=white&label=)](https://pypi.org/project/vllm-cpu/) |
| **vllm-cpu-avx512** | AVX512 | Intel Skylake-X+ | `linux/amd64` | [![PyPI](https://img.shields.io/pypi/v/vllm-cpu-avx512?logo=pypi&logoColor=white&label=)](https://pypi.org/project/vllm-cpu-avx512/) |
| **vllm-cpu-avx512vnni** | AVX512 + VNNI | Intel Cascade Lake+ | `linux/amd64` | [![PyPI](https://img.shields.io/pypi/v/vllm-cpu-avx512vnni?logo=pypi&logoColor=white&label=)](https://pypi.org/project/vllm-cpu-avx512vnni/) |
| **vllm-cpu-avx512bf16** | AVX512 + VNNI + BF16 | Intel Cooper Lake+ | `linux/amd64` | [![PyPI](https://img.shields.io/pypi/v/vllm-cpu-avx512bf16?logo=pypi&logoColor=white&label=)](https://pypi.org/project/vllm-cpu-avx512bf16/) |
| **vllm-cpu-amxbf16** | AVX512 + VNNI + BF16 + AMX | Intel Sapphire Rapids+ | `linux/amd64` | [![PyPI](https://img.shields.io/pypi/v/vllm-cpu-amxbf16?logo=pypi&logoColor=white&label=)](https://pypi.org/project/vllm-cpu-amxbf16/) |

**Performance Hierarchy:** `vllm-cpu-amxbf16` > `vllm-cpu-avx512bf16` > `vllm-cpu-avx512vnni` > `vllm-cpu-avx512` > `vllm-cpu`

---

## Which Package Should I Use?

### Quick Decision Tree

```
Is your CPU ARM64 (Graviton, Apple Silicon, Pi)?
  └─ Yes → vllm-cpu
  └─ No (x86_64) →
       Does lscpu show "amx_bf16"?
         └─ Yes → vllm-cpu-amxbf16
         └─ No →
              Does lscpu show "avx512_bf16"?
                └─ Yes → vllm-cpu-avx512bf16
                └─ No →
                     Does lscpu show "avx512vnni"?
                       └─ Yes → vllm-cpu-avx512vnni
                       └─ No →
                            Does lscpu show "avx512f"?
                              └─ Yes → vllm-cpu-avx512
                              └─ No → vllm-cpu
```

### Automatic Detection

Run this to detect your CPU features and get the install command:

```bash
pkg=vllm-cpu
grep -q avx512f /proc/cpuinfo && pkg=vllm-cpu-avx512
grep -q avx512_vnni /proc/cpuinfo && pkg=vllm-cpu-avx512vnni
grep -q avx512_bf16 /proc/cpuinfo && pkg=vllm-cpu-avx512bf16
grep -q amx_bf16 /proc/cpuinfo && pkg=vllm-cpu-amxbf16
printf "\n\tRUN:\n\t\tuv pip install $pkg\n"
```

Output example:
```
	RUN:
		uv pip install vllm-cpu-amxbf16
```

---

## Installation

### Prerequisites

- **OS:** Linux (Ubuntu 20.04+, Debian 11+, RHEL 8+, etc.)
- **Python:** 3.10, 3.11, 3.12, or 3.13
- **Windows:** Use WSL2 (Windows Subsystem for Linux)
- **macOS:** Use Docker or build from source

### Method 1: pip (Standard)

```bash
# Replace PACKAGE with your variant (vllm-cpu, vllm-cpu-avx512, etc.)
pip install PACKAGE --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

**All Variants:**

```bash
# Baseline (ARM64 + x86_64 without AVX512)
pip install vllm-cpu --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple

# AVX512 (Intel Skylake-X, AMD Zen 4+)
pip install vllm-cpu-avx512 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple

# AVX512 + VNNI (Intel Cascade Lake+)
pip install vllm-cpu-avx512vnni --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple

# AVX512 + VNNI + BF16 (Intel Cooper Lake+, AMD Zen 4 EPYC)
pip install vllm-cpu-avx512bf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple

# AVX512 + VNNI + BF16 + AMX (Intel Sapphire Rapids+)
pip install vllm-cpu-amxbf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

### Method 2: uv (Faster)

[uv](https://github.com/astral-sh/uv) is a fast Python package manager. Install it first:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then install vLLM:

```bash
uv pip install vllm-cpu-amxbf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

### Method 3: Virtual Environment (Recommended)

```bash
# Create and activate virtual environment
python -m venv vllm-env
source vllm-env/bin/activate

# Install vLLM
pip install vllm-cpu-amxbf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

### Install Specific Version

```bash
# Install specific version (e.g., 0.12.0)
pip install vllm-cpu==0.12.0 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple

# For versions 0.8.5-0.12.0, use .post2 releases (includes CPU platform fix)
pip install vllm-cpu==0.12.0.post2 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

---

## Docker Deployment

Pre-built Docker images are available on **Docker Hub** and **GitHub Container Registry**.

### Available Images

| Variant | Docker Hub | GHCR | Platforms |
|---------|------------|------|-----------|
| noavx512 | `mekayelanik/vllm-cpu:noavx512-latest` | `ghcr.io/mekayelanik/vllm-cpu:noavx512-latest` | amd64, arm64 |
| avx512 | `mekayelanik/vllm-cpu:avx512-latest` | `ghcr.io/mekayelanik/vllm-cpu:avx512-latest` | amd64 |
| avx512vnni | `mekayelanik/vllm-cpu:avx512vnni-latest` | `ghcr.io/mekayelanik/vllm-cpu:avx512vnni-latest` | amd64 |
| avx512bf16 | `mekayelanik/vllm-cpu:avx512bf16-latest` | `ghcr.io/mekayelanik/vllm-cpu:avx512bf16-latest` | amd64 |
| amxbf16 | `mekayelanik/vllm-cpu:amxbf16-latest` | `ghcr.io/mekayelanik/vllm-cpu:amxbf16-latest` | amd64 |

**Tag Format:** `<variant>-<version>` (e.g., `noavx512-0.12.0`, `amxbf16-0.11.2`)

### Quick Start with Docker

```bash
# Pull the image
docker pull mekayelanik/vllm-cpu:noavx512-latest

# Run OpenAI-compatible API server
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m \
  --host 0.0.0.0
```

### Docker with Model Cache

Mount your Hugging Face cache to avoid re-downloading models:

```bash
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=your_token_here \
  mekayelanik/vllm-cpu:amxbf16-latest \
  --model meta-llama/Llama-2-7b-chat-hf \
  --max-model-len 4096
```

### Docker with Performance Tuning

```bash
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e OMP_NUM_THREADS=16 \
  -e MKL_NUM_THREADS=16 \
  --cpus=16 \
  mekayelanik/vllm-cpu:avx512bf16-latest \
  --model mistralai/Mistral-7B-Instruct-v0.2 \
  --max-model-len 8192 \
  --dtype bfloat16
```

### Docker Compose

```yaml
---
services:
  vllm:
    image: mekayelanik/vllm-cpu:amxbf16-latest
    ports:
      - "8000:8000"
    volumes:
      - huggingface-cache:/root/.cache/huggingface
    environment:
      - OMP_NUM_THREADS=8
      - MKL_NUM_THREADS=8
      - HF_TOKEN=${HF_TOKEN}
    command: ["--model", "microsoft/phi-2", "--host", "0.0.0.0", "--max-model-len", "2048"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 32G

volumes:
  huggingface-cache:
```

### High-Performance Production Server

Optimized for **high-load production environments** on Intel Xeon (Sapphire Rapids+) or AMD EPYC servers with 32+ cores and 128+ GB RAM.

```yaml
---
services:
  vllm-cpu-prod:
    image: mekayelanik/vllm-cpu:amxbf16-latest
    container_name: vllm-cpu-prod
    restart: always
    network_mode: host
    cap_add:
      - SYS_NICE
      - IPC_LOCK
    security_opt:
      - seccomp=unconfined
    shm_size: 16g
    volumes:
      - /mnt/nvme/vllm-data:/data
      - /mnt/nvme/models:/data/models:ro
      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 4G
    environment:
      # Model
      - VLLM_MODEL=Qwen/Qwen3-8B
      - HF_HOME=/data/models
      - HF_HUB_OFFLINE=1
      # Server
      - VLLM_SERVER_HOST=0.0.0.0
      - VLLM_SERVER_PORT=8000
      - VLLM_API_KEY=${VLLM_API_KEY:-}
      # CPU Optimization (CRITICAL)
      # KV Cache: (RAM - Model Size - 8GB) / 2
      - VLLM_CPU_KVCACHE_SPACE=40
      - VLLM_CPU_OMP_THREADS_BIND=0-31
      - VLLM_CPU_NUM_OF_RESERVED_CPU=2
      # Threading (physical cores - reserved)
      - OMP_NUM_THREADS=30
      - MKL_NUM_THREADS=30
      - OMP_PROC_BIND=close
      - OMP_PLACES=cores
      # Memory
      - MALLOC_TRIM_THRESHOLD_=65536
      - LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
      # Logging
      - VLLM_LOGGING_LEVEL=WARNING
      - VLLM_NO_USAGE_STATS=1
    command:
      - "--max-model-len"
      - "32768"
      - "--dtype"
      - "bfloat16"
      - "--max-num-seqs"
      - "256"
      - "--max-num-batched-tokens"
      - "32768"
      - "--disable-log-requests"
      - "--enable-chunked-prefill"
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 1048576
        hard: 1048576
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "5"
```

**KV Cache Sizing Guide:**

| System RAM | Model Size | `VLLM_CPU_KVCACHE_SPACE` |
|------------|------------|--------------------------|
| 32 GB | 7B (~14GB) | 5 |
| 64 GB | 7B (~14GB) | 20 |
| 128 GB | 7B (~14GB) | 50 |
| 256 GB | 70B (~140GB) | 50 |

### Docker on ARM64

```bash
# For AWS Graviton, Apple Silicon, Raspberry Pi
docker pull mekayelanik/vllm-cpu:noavx512-latest

# The image auto-detects ARM64 and uses appropriate optimizations
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m
```

---

## Usage Examples

### Python API

```python
from vllm import LLM, SamplingParams

# Initialize the model
llm = LLM(
    model="microsoft/phi-2",
    device="cpu",
    dtype="bfloat16",  # Use bfloat16 for better performance on supported CPUs
    max_model_len=2048
)

# Generate text
sampling_params = SamplingParams(
    temperature=0.7,
    top_p=0.9,
    max_tokens=256
)

prompts = [
    "Explain quantum computing in simple terms:",
    "Write a Python function to reverse a string:",
]

outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    print(f"Prompt: {output.prompt}")
    print(f"Generated: {output.outputs[0].text}\n")
```

### OpenAI-Compatible Server

Start the server:

```bash
python -m vllm.entrypoints.openai.api_server \
    --model mistralai/Mistral-7B-Instruct-v0.2 \
    --device cpu \
    --host 0.0.0.0 \
    --port 8000
```

Use with OpenAI client:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.2",
    messages=[
        {"role": "user", "content": "What is the capital of France?"}
    ]
)

print(response.choices[0].message.content)
```

### cURL API Calls

```bash
# Chat completion
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.2",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Text completion
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.2",
    "prompt": "The meaning of life is",
    "max_tokens": 100
  }'
```

### Batch Processing

```python
from vllm import LLM, SamplingParams

llm = LLM(model="facebook/opt-1.3b", device="cpu")

# Process many prompts efficiently with continuous batching
prompts = [f"Question {i}: What is {i} + {i}?" for i in range(100)]
outputs = llm.generate(prompts, SamplingParams(max_tokens=50))

for output in outputs:
    print(output.outputs[0].text)
```

---

## CPU Compatibility Guide

### Intel CPUs

| Generation | Example CPUs | Recommended Package |
|------------|--------------|---------------------|
| Skylake-X (2017) | Core i9-7900X, Xeon W-2195 | `vllm-cpu-avx512` |
| Cascade Lake (2019) | Xeon Platinum 8280, Core i9-10980XE | `vllm-cpu-avx512vnni` |
| Cooper Lake (2020) | Xeon Platinum 8380H (3rd Gen) | `vllm-cpu-avx512bf16` |
| Sapphire Rapids (2023) | Xeon w9-3495X, Xeon Platinum 8480+ (4th Gen) | `vllm-cpu-amxbf16` |
| Emerald Rapids (2024) | Xeon Platinum 8592+ (5th Gen) | `vllm-cpu-amxbf16` |
| Granite Rapids (2024) | Xeon 6 (6th Gen) | `vllm-cpu-amxbf16` |
| Consumer (no AVX512) | Core i5/i7/i9 12th-14th Gen | `vllm-cpu` |

### AMD CPUs

| Generation | Example CPUs | Recommended Package |
|------------|--------------|---------------------|
| Zen 2 (2019) | Ryzen 3000, EPYC 7002 | `vllm-cpu` |
| Zen 3 (2020) | Ryzen 5000, EPYC 7003 | `vllm-cpu` |
| Zen 4 (2022) | Ryzen 7000, EPYC 9004 | `vllm-cpu-avx512` or `vllm-cpu-avx512bf16` |
| Zen 5 (2024) | Ryzen 9000, EPYC 9005 | `vllm-cpu-avx512bf16` |

**Note:** AMD CPUs do not support AMX. Use `vllm-cpu-avx512bf16` as the maximum for AMD.

### ARM CPUs

| Platform | Example | Recommended Package |
|----------|---------|---------------------|
| AWS Graviton 2/3/4 | c7g, m7g, r7g instances | `vllm-cpu` |
| Apple Silicon | M1, M2, M3, M4 (via Docker/Lima) | `vllm-cpu` |
| Ampere Altra | Various cloud instances | `vllm-cpu` |
| Raspberry Pi 4/5 | ARM Cortex-A72/A76 | `vllm-cpu` |

### Check Your CPU Features

```bash
# Linux
lscpu | grep -E "avx512|vnni|bf16|amx"

# Detailed flags
cat /proc/cpuinfo | grep flags | head -1
```

**Flag Meanings:**
- `avx512f` → AVX-512 Foundation (use `vllm-cpu-avx512`)
- `avx512vnni` → Vector Neural Network Instructions (use `vllm-cpu-avx512vnni`)
- `avx512_bf16` → BFloat16 support (use `vllm-cpu-avx512bf16`)
- `amx_bf16` → Advanced Matrix Extensions (use `vllm-cpu-amxbf16`)

---

## Performance Tips

### 1. Choose the Right Package

Using the wrong package leaves performance on the table. Always use the most optimized package your CPU supports.

### 2. Set Thread Count

```bash
# Set to number of physical cores (not threads)
export OMP_NUM_THREADS=16
export MKL_NUM_THREADS=16
```

### 3. Use BFloat16 Precision

```python
llm = LLM(model="your-model", device="cpu", dtype="bfloat16")
```

### 4. Optimize Memory

```python
llm = LLM(
    model="your-model",
    device="cpu",
    max_model_len=4096,      # Reduce if OOM
    gpu_memory_utilization=0.9  # Adjust for CPU memory
)
```

### 5. Enable NUMA Awareness

For multi-socket systems:

```bash
# Run on specific NUMA node
numactl --cpunodebind=0 --membind=0 python your_script.py
```

### 6. Use Quantized Models

```python
# INT8 quantized model for lower memory usage
llm = LLM(model="TheBloke/Llama-2-7B-GPTQ", device="cpu", quantization="gptq")
```

---

## Troubleshooting

### RuntimeError: Failed to infer device type

**Cause:** CPU platform detection issue in versions 0.8.5-0.12.0.

**Solution 1:** Use `.post2` releases (recommended):
```bash
pip install vllm-cpu==0.12.0.post2 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

**Solution 2:** Apply manual fix:
```python
import os, sys, importlib.metadata as m
v = next((d.metadata['Version'] for d in m.distributions() if d.metadata['Name'].startswith('vllm-cpu')), None)
if v:
    p = next((p for p in sys.path if 'site-packages' in p and os.path.isdir(p)), None)
    if p:
        d = os.path.join(p, 'vllm-0.0.0.dist-info'); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, 'METADATA'), 'w').write(f'Metadata-Version: 2.1\nName: vllm\nVersion: {v}+cpu\n')
        print(f'Fixed: vllm version set to {v}+cpu')
```

### Illegal Instruction Error

**Cause:** Using a package with instructions your CPU doesn't support.

**Solution:** Detect your CPU features and install the right package:
```bash
pkg=vllm-cpu
grep -q avx512f /proc/cpuinfo && pkg=vllm-cpu-avx512
grep -q avx512_vnni /proc/cpuinfo && pkg=vllm-cpu-avx512vnni
grep -q avx512_bf16 /proc/cpuinfo && pkg=vllm-cpu-avx512bf16
grep -q amx_bf16 /proc/cpuinfo && pkg=vllm-cpu-amxbf16
printf "\n\tRUN:\n\t\tuv pip install $pkg\n"
```

### Out of Memory (OOM)

**Solution:** Reduce model memory usage:
```python
llm = LLM(
    model="your-model",
    device="cpu",
    max_model_len=2048,  # Reduce context length
    dtype="bfloat16"     # Use lower precision
)
```

### Slow Performance

**Checklist:**
1. Are you using the most optimized package for your CPU?
2. Are `OMP_NUM_THREADS` and `MKL_NUM_THREADS` set correctly?
3. Is the model quantized (GPTQ/AWQ) for faster inference?
4. Are you on a NUMA system without proper binding?

### Multiple vLLM Packages Conflict

**Solution:** Remove all and reinstall:
```bash
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y
pip install vllm-cpu-amxbf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

---

## Supported Models

vLLM supports 100+ models including:

| Category | Models |
|----------|--------|
| **LLMs** | Llama 2/3/3.1/3.2, Mistral, Mixtral, Qwen 2/2.5/3, Phi-2/3/4, Gemma/Gemma 2/Gemma 3, DeepSeek V2/V3/R1, Yi, Falcon, Command-R |
| **Reasoning** | DeepSeek-R1, DeepSeek-R1-Distill, Qwen3 (with thinking mode), QwQ |
| **Medical** | MedGemma, BioMistral, Med-PaLM (via API) |
| **Embedding** | E5-Mistral, GTE, BGE, Nomic-Embed, Jina |
| **Multimodal** | LLaVA, LLaVA-NeXT, Qwen-VL, Qwen2.5-VL, InternVL, Pixtral, MiniCPM-V, Molmo |
| **Code** | CodeLlama, DeepSeek-Coder, StarCoder 1/2, CodeGemma, Codestral, Qwen2.5-Coder |
| **MoE** | Mixtral 8x7B/8x22B, DeepSeek-MoE, Qwen-MoE, DBRX, Arctic, DeepSeek-V3 |

Full list: [vLLM Supported Models](https://docs.vllm.ai/en/latest/models/supported_models.html)

---

## Instruction Set Deep Dive

Understanding what each instruction set provides helps you make informed decisions.

### AVX-512 Foundation

AVX-512 (Advanced Vector Extensions 512) extends SIMD (Single Instruction, Multiple Data) operations to 512-bit registers, doubling the width from AVX2's 256-bit registers. This means:

- **2x wider vectors**: Process 16 floats or 8 doubles per instruction
- **32 vector registers**: Up from 16 in AVX2
- **Mask registers**: Efficient conditional operations

**Impact on LLM inference**: Matrix multiplications and attention computations run faster with wider vectors.

### VNNI (Vector Neural Network Instructions)

VNNI adds specialized instructions for neural network inference:

- **VPDPBUSD**: Multiply-accumulate for INT8 data
- **VPDPWSSD**: Multiply-accumulate for INT16 data

**Impact on LLM inference**: Faster quantized (INT8) inference, reduced memory bandwidth requirements.

### BF16 (Brain Float 16)

BFloat16 is a 16-bit floating-point format optimized for deep learning:

- Same range as FP32 (8 exponent bits)
- Lower precision (7 mantissa bits vs 23)
- 2x memory efficiency compared to FP32

**Impact on LLM inference**: Faster training and inference with minimal accuracy loss, half the memory usage.

### AMX (Advanced Matrix Extensions)

AMX introduces tile-based matrix operations with dedicated accelerators:

- **Tile registers**: 8 tile registers of 1KB each
- **TMUL**: Tile matrix multiply unit
- **Native BF16 support**: Fast BF16 matrix operations

**Impact on LLM inference**: 2-8x faster matrix operations compared to AVX-512 alone, especially for transformer attention layers.

---

## Advanced Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OMP_NUM_THREADS` | OpenMP thread count | All cores |
| `MKL_NUM_THREADS` | Intel MKL thread count | All cores |
| `VLLM_CPU_KVCACHE_SPACE` | KV cache size in GB | 4 |
| `VLLM_CPU_OMP_THREADS_BIND` | Thread binding strategy | auto |
| `HF_TOKEN` | Hugging Face access token | None |
| `HF_HOME` | Hugging Face cache directory | ~/.cache/huggingface |

### Server Configuration

```bash
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-2-7b-chat-hf \
    --device cpu \
    --host 0.0.0.0 \
    --port 8000 \
    --max-model-len 4096 \
    --dtype bfloat16 \
    --max-num-seqs 256 \
    --max-num-batched-tokens 32768 \
    --disable-log-requests
```

### Multi-LoRA Serving

Serve multiple LoRA adapters from a single base model:

```python
from vllm import LLM, SamplingParams
from vllm.lora.request import LoRARequest

llm = LLM(
    model="meta-llama/Llama-2-7b-hf",
    device="cpu",
    enable_lora=True,
    max_loras=4
)

# Serve different LoRAs for different requests
lora_request = LoRARequest("sql-lora", 1, "/path/to/sql-lora")
outputs = llm.generate(
    ["Write a SQL query to..."],
    SamplingParams(max_tokens=100),
    lora_request=lora_request
)
```

### Speculative Decoding

Use a smaller draft model to accelerate generation:

```python
llm = LLM(
    model="meta-llama/Llama-2-70b-chat-hf",
    device="cpu",
    speculative_model="meta-llama/Llama-2-7b-chat-hf",
    num_speculative_tokens=5
)
```

---

## Benchmarking

### Quick Performance Test

```python
import time
from vllm import LLM, SamplingParams

llm = LLM(model="facebook/opt-1.3b", device="cpu")

prompts = ["Hello, my name is"] * 10
sampling_params = SamplingParams(max_tokens=100)

start = time.time()
outputs = llm.generate(prompts, sampling_params)
elapsed = time.time() - start

total_tokens = sum(len(o.outputs[0].token_ids) for o in outputs)
print(f"Generated {total_tokens} tokens in {elapsed:.2f}s")
print(f"Throughput: {total_tokens/elapsed:.2f} tokens/sec")
```

### Single Board Computers (Raspberry Pi, etc.)

For Raspberry Pi 4B, Pi 5, and similar ARM-based SBCs, use **GGUF quantized models** for optimal performance on resource-constrained devices. vLLM supports GGUF format experimentally.

**Recommended Models for SBCs:**

| Model | Size | Context | Type | Best For |
|-------|------|---------|------|----------|
| gemma3:270m | 292 MB | 32K | Text | Pi 4B (2GB+), ultra-lightweight |
| smollm2:135m | 271 MB | 8K | Text | Pi 4B (2GB+), fastest responses |
| smollm2:360m | 726 MB | 8K | Text | Pi 4B (4GB+), balanced |
| qwen3:0.6b | 523 MB | 40K | Text | Pi 4B (4GB+), long context |
| gemma3:1b | 815 MB | 32K | Text | Pi 5 (4GB+), good quality |
| deepseek-r1:1.5b | 1.1 GB | 128K | Text | Pi 5 (4GB+), reasoning tasks |
| qwen3:1.7b | 1.4 GB | 40K | Text | Pi 5 (8GB), best quality |
| smollm2:1.7b | 1.8 GB | 8K | Text | Pi 5 (8GB), general use |
| ministral-3b | 3.0 GB | 256K | Text, Image | Pi 5 (8GB), multimodal |

**Running GGUF Models with vLLM:**

```bash
# Download a GGUF model
wget https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf

# Run with vLLM (use base model tokenizer for best results)
python -m vllm.entrypoints.openai.api_server \
    --model ./gemma-3-1b-it-Q4_K_M.gguf \
    --tokenizer google/gemma-3-1b-it \
    --device cpu \
    --host 0.0.0.0 \
    --port 8000
```

**Docker Compose for SBCs:**

```yaml
---
services:
  vllm-sbc:
    image: mekayelanik/vllm-cpu:noavx512-latest
    ports:
      - "8000:8000"
    volumes:
      - ./models:/models
      - huggingface-cache:/root/.cache/huggingface
    environment:
      - OMP_NUM_THREADS=4
      - MKL_NUM_THREADS=4
    command: [
      "--model", "/models/gemma-3-1b-it-Q4_K_M.gguf",
      "--tokenizer", "google/gemma-3-1b-it",
      "--host", "0.0.0.0",
      "--port", "8000",
      "--max-model-len", "2048"
    ]
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 4G

volumes:
  huggingface-cache:
```

**Setup:**
```bash
# Create models directory and download GGUF
mkdir -p models
wget -O models/gemma-3-1b-it-Q4_K_M.gguf \
  https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf

# Start the server
docker compose up -d
```

**Why GGUF for SBCs?**
- 4-bit/8-bit quantization reduces memory usage significantly
- Smaller model footprint fits in limited RAM (2-8GB)
- Enables running LLMs on devices with no GPU

---

## Building From Source

For custom builds or unsupported configurations:

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y gcc-14 g++-14 cmake ninja-build ccache \
    libtcmalloc-minimal4 libnuma-dev numactl git jq

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Build Wheel

```bash
git clone https://github.com/MekayelAnik/vllm-cpu.git
cd vllm-cpu

# Build specific variant
./build_wheels.sh --variant=vllm-cpu-amxbf16 --vllm-versions=0.12.0

# Build all variants
./build_wheels.sh --variant=all --vllm-versions=0.12.0
```

### Docker Build

```bash
# Build using Docker buildx (recommended)
./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.12.0

# Build for specific platform
./docker-buildx.sh --variant=vllm-cpu --platform=linux/arm64 --vllm-version=0.12.0
```

---

## FAQ

### Can I use this on Windows?

Not directly. Use WSL2 (Windows Subsystem for Linux) to run Linux binaries on Windows. Docker Desktop with WSL2 backend also works.

### What's the minimum RAM required?

Depends on the model:
- Small models (125M-1B): 4-8 GB
- Medium models (7B): 16-32 GB
- Large models (13B-70B): 64-256 GB

### Can I run multiple models?

Yes, but each model loads into memory separately. Consider using Multi-LoRA serving for efficient variant serving from a single base model.

### Is GPU inference supported?

No. These packages are CPU-only. For GPU inference, use the official [vLLM package](https://pypi.org/project/vllm/).

### How do I update to a new version?

```bash
pip uninstall vllm-cpu-amxbf16 -y
pip install vllm-cpu-amxbf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
```

### Why are there 5 different packages?

Different CPUs support different instruction sets. Using the optimal package for your CPU provides significant performance improvements. Installing the wrong package (e.g., AMX on a non-AMX CPU) causes illegal instruction crashes.

---

## Cloud Deployment Examples

### AWS EC2

**Recommended Instances:**

| Instance Type | vCPUs | RAM | Package | Use Case |
|---------------|-------|-----|---------|----------|
| c7i.4xlarge | 16 | 32 GB | vllm-cpu-amxbf16 | 7B models |
| c7i.8xlarge | 32 | 64 GB | vllm-cpu-amxbf16 | 7B-13B models |
| c7i.16xlarge | 64 | 128 GB | vllm-cpu-amxbf16 | 13B-70B models |
| c7g.4xlarge | 16 | 32 GB | vllm-cpu | ARM64, 7B models |
| c6i.8xlarge | 32 | 64 GB | vllm-cpu-avx512vnni | 7B-13B models |

```bash
# Launch and setup (Ubuntu 22.04 AMI)
ssh ec2-user@your-instance

# Install dependencies
sudo apt update && sudo apt install -y python3-pip
pip install vllm-cpu-amxbf16 --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple

# Set optimal threading
export OMP_NUM_THREADS=$(nproc --all)
export MKL_NUM_THREADS=$(nproc --all)

# Run server
python -m vllm.entrypoints.openai.api_server \
    --model mistralai/Mistral-7B-Instruct-v0.2 \
    --device cpu \
    --host 0.0.0.0
```

### Google Cloud Platform

**Recommended Machine Types:**

| Machine Type | vCPUs | RAM | Package |
|--------------|-------|-----|---------|
| c3-standard-22 | 22 | 88 GB | vllm-cpu-amxbf16 |
| c3-standard-44 | 44 | 176 GB | vllm-cpu-amxbf16 |
| t2a-standard-16 | 16 | 64 GB | vllm-cpu (ARM) |
| n2-standard-32 | 32 | 128 GB | vllm-cpu-avx512vnni |

### Azure

**Recommended VM Sizes:**

| VM Size | vCPUs | RAM | Package |
|---------|-------|-----|---------|
| Standard_D32s_v5 | 32 | 128 GB | vllm-cpu-avx512vnni |
| Standard_E32s_v5 | 32 | 256 GB | vllm-cpu-avx512vnni |
| Standard_DC32s_v3 | 32 | 256 GB | vllm-cpu-amxbf16 |

---

## Kubernetes Deployment

### Basic Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-cpu
  labels:
    app: vllm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm
  template:
    metadata:
      labels:
        app: vllm
    spec:
      containers:
      - name: vllm
        image: mekayelanik/vllm-cpu:amxbf16-latest
        ports:
        - containerPort: 8000
        args:
          - "--model"
          - "microsoft/phi-2"
          - "--host"
          - "0.0.0.0"
          - "--max-model-len"
          - "2048"
        env:
        - name: OMP_NUM_THREADS
          value: "8"
        - name: MKL_NUM_THREADS
          value: "8"
        - name: HF_TOKEN
          valueFrom:
            secretKeyRef:
              name: hf-secret
              key: token
        resources:
          requests:
            cpu: "8"
            memory: "32Gi"
          limits:
            cpu: "16"
            memory: "64Gi"
        volumeMounts:
        - name: model-cache
          mountPath: /root/.cache/huggingface
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 5
      volumes:
      - name: model-cache
        persistentVolumeClaim:
          claimName: model-cache-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-service
spec:
  selector:
    app: vllm
  ports:
  - port: 80
    targetPort: 8000
  type: LoadBalancer
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vllm-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vllm-cpu
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

## Integration Examples

### LangChain

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed",
    model="mistralai/Mistral-7B-Instruct-v0.2"
)

response = llm.invoke("Explain machine learning in simple terms")
print(response.content)
```

### LlamaIndex

```python
from llama_index.llms.openai_like import OpenAILike

llm = OpenAILike(
    api_base="http://localhost:8000/v1",
    api_key="not-needed",
    model="mistralai/Mistral-7B-Instruct-v0.2"
)

response = llm.complete("What is the capital of France?")
print(response.text)
```

### Semantic Kernel

```python
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.open_ai import OpenAIChatCompletion

kernel = Kernel()
kernel.add_service(OpenAIChatCompletion(
    service_id="vllm",
    ai_model_id="mistralai/Mistral-7B-Instruct-v0.2",
    base_url="http://localhost:8000/v1",
    api_key="not-needed"
))
```

---

## Security Considerations

### Running as Non-Root

The Docker images run as a non-root user (`vllm`) by default for security.

### Network Security

```bash
# Bind to localhost only (recommended for development)
python -m vllm.entrypoints.openai.api_server \
    --model your-model \
    --device cpu \
    --host 127.0.0.1

# Use reverse proxy (nginx) for production
# Never expose vLLM directly to the internet
```

### API Key Authentication

vLLM supports optional API key authentication:

```bash
python -m vllm.entrypoints.openai.api_server \
    --model your-model \
    --device cpu \
    --api-key your-secret-key
```

### Rate Limiting

Use a reverse proxy like nginx for rate limiting:

```nginx
limit_req_zone $binary_remote_addr zone=vllm:10m rate=10r/s;

server {
    location /v1/ {
        limit_req zone=vllm burst=20 nodelay;
        proxy_pass http://localhost:8000;
    }
}
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

See [CONTRIBUTING.md](https://github.com/MekayelAnik/vllm-cpu/blob/main/CONTRIBUTING.md) for detailed guidelines.

---

## Changelog

See [GitHub Releases](https://github.com/MekayelAnik/vllm-cpu/releases) for version history and release notes.

---

## Links & Resources

| Resource | Link |
|----------|------|
| **GitHub Repository** | [github.com/MekayelAnik/vllm-cpu](https://github.com/MekayelAnik/vllm-cpu) |
| **Docker Hub** | [hub.docker.com/r/mekayelanik/vllm-cpu](https://hub.docker.com/r/mekayelanik/vllm-cpu) |
| **GHCR** | [ghcr.io/mekayelanik/vllm-cpu](https://ghcr.io/mekayelanik/vllm-cpu) |
| **vLLM Documentation** | [docs.vllm.ai](https://docs.vllm.ai/en/latest/) |
| **Upstream vLLM** | [github.com/vllm-project/vllm](https://github.com/vllm-project/vllm) |

### PyPI Packages

| Package | PyPI Link |
|---------|-----------|
| vllm-cpu | [pypi.org/project/vllm-cpu](https://pypi.org/project/vllm-cpu/) |
| vllm-cpu-avx512 | [pypi.org/project/vllm-cpu-avx512](https://pypi.org/project/vllm-cpu-avx512/) |
| vllm-cpu-avx512vnni | [pypi.org/project/vllm-cpu-avx512vnni](https://pypi.org/project/vllm-cpu-avx512vnni/) |
| vllm-cpu-avx512bf16 | [pypi.org/project/vllm-cpu-avx512bf16](https://pypi.org/project/vllm-cpu-avx512bf16/) |
| vllm-cpu-amxbf16 | [pypi.org/project/vllm-cpu-amxbf16](https://pypi.org/project/vllm-cpu-amxbf16/) |

---

## License

- **This project:** [GPL-3.0](https://github.com/MekayelAnik/vllm-cpu/blob/main/LICENSE)
- **Upstream vLLM:** [Apache-2.0](https://github.com/vllm-project/vllm/blob/main/LICENSE)

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating and maintaining open-source projects.**
If you found value in this project, consider buying me a coffee to fuel those sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="217" height="60">
</a>

</div>

---

<p align="center">
  <sub>Originally developed at <a href="https://sky.cs.berkeley.edu">Sky Computing Lab</a>, UC Berkeley</sub>
</p>
