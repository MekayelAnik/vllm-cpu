<!-- markdownlint-disable MD001 MD041 -->
<p align="center">
  <img alt="vLLM" src="https://raw.githubusercontent.com/vllm-project/vllm/main/docs/assets/logos/vllm-logo-text-light.png" width="55%">
</p>

<h3 align="center">
CPU-Optimized vLLM: Easy, Fast LLM Inference Without a GPU
</h3>

<p align="center">
  <strong>Unified CPU wheel with automatic ISA detection at runtime (AVX2, AVX-512, VNNI, BF16, AMX, NEON)</strong>
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
</p>

---

## Overview

**vllm-cpu** provides unified CPU wheels for [vLLM](https://github.com/vllm-project/vllm) on PyPI. One package, one `pip install`, automatic CPU instruction set detection.

**Why CPU inference?**
- No expensive GPU required
- Run LLMs on any server, laptop, or edge device
- Lower power consumption and operational costs
- Ideal for development, testing, and moderate-scale deployments
- ARM64 support for AWS Graviton 3+, Apple Silicon, and Ampere (BF16-capable ARM)

**Key Features:**
- `pip install vllm-cpu` -- no manual URLs or GitHub Release downloads
- Built with `manylinux_2_28` for broad compatibility (Debian 10+, Ubuntu 18.04+)
- Stable ABI (cp38-abi3) -- one wheel for Python 3.10+
- Automatic AVX2 / AVX512 / AMX detection at runtime

---

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Supported CPU Instructions](#supported-cpu-instructions)
- [CPU Compatibility Guide](#cpu-compatibility-guide)
- [Usage Examples](#usage-examples)
- [Performance Tips](#performance-tips)
- [Environment Variables](#environment-variables)
- [Supported Models](#supported-models)
- [Framework Integrations](#framework-integrations)
- [Version Support](#version-support)
- [Troubleshooting](#troubleshooting)
- [Links & Resources](#links--resources)

---

## Quick Start

**1. Install**

```bash
pip install vllm-cpu
```

**2. Run your first model**

```python
from vllm import LLM, SamplingParams

llm = LLM(model="Qwen/Qwen3-0.6B", dtype="bfloat16")
outputs = llm.generate(["Hello, my name is"], SamplingParams(max_tokens=50))
print(outputs[0].outputs[0].text)
```

**3. Or start an OpenAI-compatible server**

```bash
vllm serve Qwen/Qwen3-0.6B --dtype auto
```

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen3-0.6B", "prompt": "The future of AI is", "max_tokens": 128}'
```

---

## Installation

### Prerequisites

| Requirement | Details |
|-------------|---------|
| **Python** | 3.10+ (stable ABI -- one wheel for all versions) |
| **OS** | Linux (glibc 2.28+) -- Debian 10+, Ubuntu 18.04+, RHEL 8+, Amazon Linux 2023+ |
| **CPU** | x86_64 with AVX2 (minimum) or AVX512 (optimal), or aarch64 |
| **Windows** | Use WSL2 (Windows Subsystem for Linux) |

### pip

```bash
pip install vllm-cpu                # Latest
pip install vllm-cpu==0.17.0        # Specific version
```

### uv (faster)

```bash
uv pip install vllm-cpu
```

### Virtual environment (recommended)

```bash
python -m venv vllm-env && source vllm-env/bin/activate
pip install vllm-cpu
```

---

## Supported CPU Instructions

The unified wheel automatically detects and uses the best available instruction set at import time.
**No configuration needed.**

| | CPU Feature | Benefit |
|---|-------------|---------|
| **Baseline** | AVX2 | 256-bit SIMD -- works on all modern x86_64 |
| **Faster** | AVX512 | 512-bit vectors -- 2x wider than AVX2 |
| **Faster** | AVX512-VNNI | INT8 multiply-accumulate for quantized inference |
| **Faster** | AVX512-BF16 | Native BFloat16 -- half the memory of FP32 |
| **Fastest** | AMX-BF16 | Tile-based matrix acceleration (Sapphire Rapids+) |
| **ARM** | aarch64 NEON | ARM SIMD for Graviton, Apple Silicon, Ampere |

> **How it works:** The wheel ships `_C.so` (AVX512+BF16+VNNI+AMX) and `_C_AVX2.so` (AVX2 fallback). At `import vllm`, the correct `.so` is loaded once based on CPU capabilities. Zero runtime overhead.

### Check your CPU

```bash
lscpu | grep -E "avx512|vnni|bf16|amx"
```

---

## CPU Compatibility Guide

### Intel

| Generation | Example CPUs | ISA Used |
|:-----------|:-------------|:---------|
| Haswell+ (2013) | Core i5/i7 4th--11th Gen | AVX2 |
| Skylake-X (2017) | Core i9-7900X, Xeon W-2195 | AVX512 |
| Cascade Lake (2019) | Xeon Platinum 8280 | AVX512 + VNNI |
| Cooper Lake (2020) | Xeon Platinum 8380H | AVX512 + BF16 |
| Sapphire Rapids+ (2023) | Xeon w9-3495X, 4th/5th/6th Gen Xeon | **AVX512 + AMX** |
| Consumer 12th--14th Gen | Core i5/i7/i9 (Alder Lake+) | AVX2 |

### AMD

| Generation | Example CPUs | ISA Used |
|:-----------|:-------------|:---------|
| Zen 2/3 (2019--2020) | Ryzen 3000--5000, EPYC 7002--7003 | AVX2 |
| Zen 4+ (2022+) | Ryzen 7000+, EPYC 9004+ | AVX512 + BF16 |

### ARM

| Platform | Example | ISA Used |
|:---------|:--------|:---------|
| AWS Graviton 2/3/4 | c7g, m7g instances | NEON |
| Apple Silicon | M1--M4 (via Docker/Lima) | NEON |
| Ampere Altra | Cloud instances | NEON |

---

## Usage Examples

### Batch Processing

```python
from vllm import LLM, SamplingParams

llm = LLM(
    model="google/gemma-3-1b-it",
    dtype="bfloat16",
    max_model_len=2048
)

prompts = [
    "Explain quantum computing in simple terms:",
    "Write a Python function to reverse a string:",
]

outputs = llm.generate(prompts, SamplingParams(temperature=0.7, max_tokens=256))
for output in outputs:
    print(f"Prompt: {output.prompt}")
    print(f"Generated: {output.outputs[0].text}\n")
```

### OpenAI Python Client

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8000/v1", api_key="not-needed")

response = client.chat.completions.create(
    model="Qwen/Qwen3-4B",
    messages=[{"role": "user", "content": "What is the capital of France?"}]
)
print(response.choices[0].message.content)
```

### cURL

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen3-4B",
       "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## Performance Tips

### 1. Use TCMalloc (strongly recommended)

> **Official recommendation:** vLLM strongly recommends TCMalloc for high-performance memory allocation and better cache locality.

```bash
# Install
sudo apt install libtcmalloc-minimal4        # Debian/Ubuntu
sudo dnf install gperftools-libs              # RHEL/Fedora

# Preload
export LD_PRELOAD=$(find /usr -name "libtcmalloc_minimal.so*" | head -1)
vllm serve your-model --dtype auto
```

### 2. Set thread count to physical cores

> **Tip:** Disable hyper-threading on bare-metal for best performance. Reserve 1--2 cores for the HTTP serving framework.

```bash
export OMP_NUM_THREADS=16                     # Physical core count
export MKL_NUM_THREADS=16
export VLLM_CPU_OMP_THREADS_BIND=0-13         # Pin inference threads
export VLLM_CPU_NUM_OF_RESERVED_CPU=2          # Reserve for HTTP serving
```

### 3. Use BFloat16

> **Note:** Float16 is unstable on CPU. Always use `bfloat16`.

```python
llm = LLM(model="your-model", dtype="bfloat16")
```

### 4. NUMA optimization (multi-socket systems)

```bash
# Simple: bind to one NUMA node
numactl --cpunodebind=0 --membind=0 python your_script.py

# Advanced: Tensor Parallel across NUMA nodes
VLLM_CPU_OMP_THREADS_BIND=0-31|32-63 vllm serve your-model \
  --dtype auto --tensor-parallel-size 2
```

### 5. Tune KV cache

```bash
export VLLM_CPU_KVCACHE_SPACE=40              # 40 GB for KV cache
```

### 6. SGL kernels (x86, experimental)

```bash
export VLLM_CPU_SGL_KERNEL=1                  # Low-latency online serving
```

### 7. Quantized models

```python
llm = LLM(model="Qwen/Qwen3-8B-GPTQ-Int4", quantization="gptq")
```

### Memory Estimation

| Model Size | bfloat16 | GPTQ INT4 |
|:-----------|:---------|:----------|
| 1B params | ~4 GB | ~2 GB |
| 7B params | ~16 GB | ~6 GB |
| 13B params | ~28 GB | ~10 GB |
| 70B params | ~140 GB | ~40 GB |

> *Add 2--8 GB for KV cache depending on `VLLM_CPU_KVCACHE_SPACE` and context length.*

---

## Environment Variables

| Variable | Description | Default |
|:---------|:------------|:--------|
| `VLLM_CPU_KVCACHE_SPACE` | KV cache size in GB (larger = more concurrent requests) | 0 (auto) |
| `VLLM_CPU_OMP_THREADS_BIND` | CPU core binding (`0-31`, `auto`, or `nobind`) | auto |
| `VLLM_CPU_NUM_OF_RESERVED_CPU` | Cores reserved for HTTP serving (when bind=auto) | 0 |
| `VLLM_CPU_SGL_KERNEL` | Small-batch optimized kernels (x86, experimental) | 0 |
| `OMP_NUM_THREADS` | OpenMP thread count | All cores |
| `MKL_NUM_THREADS` | Intel MKL thread count | All cores |
| `LD_PRELOAD` | Preload TCMalloc for better memory performance | -- |
| `HF_TOKEN` | Hugging Face access token | -- |
| `HF_HOME` | Hugging Face cache directory | ~/.cache/huggingface |

---

## Supported Models

vLLM supports **100+ model architectures** including:

| Category | Models |
|:---------|:-------|
| **LLMs** | Llama 2/3/3.1/3.2, Mistral, Mixtral, Qwen 2/2.5/3, Phi-2/3/4, Gemma 2/3, DeepSeek V2/V3/R1 |
| **Code** | CodeLlama, DeepSeek-Coder, StarCoder 1/2, CodeGemma, Qwen2.5-Coder |
| **Embedding** | E5-Mistral, GTE, BGE, Nomic-Embed, Jina |
| **Multimodal** | LLaVA, Qwen-VL, Qwen2.5-VL, InternVL, Pixtral, MiniCPM-V |
| **MoE** | Mixtral 8x7B/8x22B, DeepSeek-MoE, Qwen-MoE, DBRX |

> Full list: **[vLLM Supported Models](https://docs.vllm.ai/en/latest/models/supported_models.html)**

---

## Framework Integrations

vLLM's server is fully **OpenAI API-compatible**. Any client that supports `base_url` override works out of the box.

### LangChain

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed",
    model="Qwen/Qwen3-4B"
)
response = llm.invoke("Explain machine learning in simple terms")
```

### LlamaIndex

```python
from llama_index.llms.openai_like import OpenAILike

llm = OpenAILike(
    api_base="http://localhost:8000/v1",
    api_key="not-needed",
    model="Qwen/Qwen3-4B"
)
response = llm.complete("What is the capital of France?")
```

> Also works with: **Semantic Kernel**, **AutoGen**, **CrewAI**, **Haystack**, and any OpenAI-compatible SDK.

---

## Version Support

| Version Range | Strategy | Status |
|:--------------|:---------|:-------|
| **v0.17.0+** | Unified CPU wheel (this package) | **Active** |
| v0.8.5 -- v0.15.x | Legacy 5-variant wheels | Archived on PyPI |

> Legacy packages (`vllm-cpu-avx512`, `vllm-cpu-avx512vnni`, `vllm-cpu-avx512bf16`, `vllm-cpu-amxbf16`) remain on PyPI for older vLLM versions but are no longer updated.

---

## Troubleshooting

### Illegal Instruction Error

The unified wheel auto-detects CPU capabilities. If you still see this:

```bash
lscpu | grep -E "avx512|vnni|bf16|amx"    # Check supported features
```

> If no AVX2 flags appear, your CPU is too old for vLLM CPU inference.

### Out of Memory (OOM)

```python
llm = LLM(model="your-model", max_model_len=2048, dtype="bfloat16")
```

```bash
export VLLM_CPU_KVCACHE_SPACE=2               # Reduce KV cache
```

### Slow Performance Checklist

| Check | Command / Fix |
|:------|:-------------|
| TCMalloc loaded? | `echo $LD_PRELOAD` -- should show libtcmalloc |
| Thread count correct? | `echo $OMP_NUM_THREADS` -- should equal physical cores |
| Hyper-threading disabled? | Recommended for bare-metal |
| Cross-NUMA access? | Use `VLLM_CPU_OMP_THREADS_BIND` to pin to one node |
| Using bfloat16? | Float16 is unstable on CPU -- always use `dtype="bfloat16"` |

### Multiple vLLM Packages Conflict

```bash
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y
pip install vllm-cpu
```

### RuntimeError: Failed to infer device type

For legacy versions (v0.8.5--v0.15.x), use `.post2` releases:

```bash
pip install vllm-cpu==0.12.0.post2
```

---

## Links & Resources

| | Resource | Link |
|---|:---------|:-----|
| **Source** | GitHub Repository | [github.com/MekayelAnik/vllm-cpu](https://github.com/MekayelAnik/vllm-cpu) |
| **Docker** | Docker Hub Images | [hub.docker.com/r/mekayelanik/vllm-cpu](https://hub.docker.com/r/mekayelanik/vllm-cpu) |
| **GHCR** | GitHub Container Registry | [ghcr.io/mekayelanik/vllm-cpu](https://github.com/MekayelAnik/vllm-cpu/pkgs/container/vllm-cpu) |
| **Docs** | vLLM Documentation | [docs.vllm.ai](https://docs.vllm.ai/en/latest/) |
| **Upstream** | vLLM Project | [github.com/vllm-project/vllm](https://github.com/vllm-project/vllm) |
| **Issues** | Report a Bug | [github.com/MekayelAnik/vllm-cpu/issues](https://github.com/MekayelAnik/vllm-cpu/issues) |
| **Releases** | Changelog | [GitHub Releases](https://github.com/MekayelAnik/vllm-cpu/releases) |

---

<p align="center">
  <strong>License:</strong> <a href="https://github.com/MekayelAnik/vllm-cpu/blob/main/LICENSE">GPL-3.0</a> | <strong>Upstream:</strong> <a href="https://github.com/vllm-project/vllm/blob/main/LICENSE">Apache-2.0</a>
</p>

<p align="center">
  <sub>Built from <a href="https://github.com/vllm-project/vllm">vLLM</a>, originally developed at <a href="https://sky.cs.berkeley.edu">Sky Computing Lab</a>, UC Berkeley</sub>
</p>
