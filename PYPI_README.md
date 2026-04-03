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
  <strong>Unified CPU wheel with automatic AVX2/AVX512 detection at runtime</strong>
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
  <a href="https://github.com/MekayelAnik/vllm-cpu/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/MekayelAnik/vllm-cpu?style=for-the-badge&logo=gnu&logoColor=white&labelColor=2b3137&color=a32d2a" alt="License">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/commits/main">
    <img src="https://img.shields.io/github/last-commit/MekayelAnik/vllm-cpu?style=for-the-badge&logo=git&logoColor=white&labelColor=2b3137&color=ff6f00" alt="Last Commit">
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
- ARM64 support for AWS Graviton, Apple Silicon, and Raspberry Pi

**Key Features:**
- `pip install vllm-cpu` -- no manual URLs or GitHub Release downloads
- Built with `manylinux_2_28` for broad compatibility (Debian 10+, Ubuntu 18.04+)
- Stable ABI (cp38-abi3) -- one wheel for Python 3.8+
- Automatic AVX2/AVX512/AMX detection at runtime

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

### 1. Install

```bash
pip install vllm-cpu
```

### 2. Run Your First Model

```python
from vllm import LLM, SamplingParams

llm = LLM(model="facebook/opt-125m", device="cpu")
outputs = llm.generate(["Hello, my name is"], SamplingParams(max_tokens=50))
print(outputs[0].outputs[0].text)
```

### 3. Or Start an OpenAI-Compatible Server

```bash
vllm serve facebook/opt-125m --device cpu --dtype auto
```

Query it:

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "facebook/opt-125m", "prompt": "The future of AI is", "max_tokens": 128}'
```

---

## Installation

### Prerequisites

- **Python**: 3.8+ (stable ABI -- one wheel for all versions)
- **OS**: Linux (glibc 2.28+) -- Debian 10+, Ubuntu 18.04+, RHEL 8+, Amazon Linux 2023+
- **CPU**: x86_64 with AVX2 (minimum) or AVX512 (optimal), or aarch64
- **Windows**: Use WSL2 (Windows Subsystem for Linux)

### pip

```bash
# Latest
pip install vllm-cpu

# Specific version
pip install vllm-cpu==0.17.0
```

### uv (faster)

```bash
uv pip install vllm-cpu
```

### Virtual environment (recommended)

```bash
python -m venv vllm-env
source vllm-env/bin/activate
pip install vllm-cpu
```

---

## Supported CPU Instructions

The unified wheel automatically detects and uses the best available instruction set at import time. **No configuration needed.**

| CPU Feature | Support | Benefit |
|-------------|---------|---------|
| AVX2 | Baseline (all x86_64) | 256-bit SIMD operations |
| AVX512 | Optimal | 512-bit vectors, 2x wider than AVX2 |
| AVX512-VNNI | Enhanced | INT8 multiply-accumulate for quantized inference |
| AVX512-BF16 | Enhanced | Native BFloat16, half the memory of FP32 |
| AMX-BF16 | Maximum | Tile-based matrix acceleration (Sapphire Rapids+) |
| aarch64 NEON | ARM baseline | ARM SIMD operations |

### How detection works

1. The wheel ships `_C.so` (AVX512+BF16+VNNI+AMX) and `_C_AVX2.so` (AVX2 fallback)
2. At `import vllm`, `vllm/platforms/cpu.py` checks `torch._C._cpu._is_avx512_supported()`
3. The correct `.so` is loaded once -- zero runtime dispatch overhead

### Check your CPU

```bash
lscpu | grep -E "avx512|vnni|bf16|amx"
```

---

## CPU Compatibility Guide

### Intel CPUs

| Generation | Example CPUs | ISA Used |
|------------|--------------|----------|
| Haswell+ (2013) | Core i5/i7 4th-11th Gen | AVX2 |
| Skylake-X (2017) | Core i9-7900X, Xeon W-2195 | AVX512 |
| Cascade Lake (2019) | Xeon Platinum 8280 | AVX512 + VNNI |
| Cooper Lake (2020) | Xeon Platinum 8380H | AVX512 + BF16 |
| Sapphire Rapids+ (2023) | Xeon w9-3495X, 4th/5th/6th Gen Xeon | AVX512 + AMX |
| Consumer 12th-14th Gen | Core i5/i7/i9 | AVX2 (no AVX512) |

### AMD CPUs

| Generation | Example CPUs | ISA Used |
|------------|--------------|----------|
| Zen 2/3 (2019-2020) | Ryzen 3000-5000, EPYC 7002-7003 | AVX2 |
| Zen 4+ (2022+) | Ryzen 7000+, EPYC 9004+ | AVX512 + BF16 |

### ARM CPUs

| Platform | Example | ISA Used |
|----------|---------|----------|
| AWS Graviton 2/3/4 | c7g, m7g instances | NEON |
| Apple Silicon | M1-M4 (via Docker/Lima) | NEON |
| Ampere Altra | Cloud instances | NEON |

---

## Supported Platforms

| Platform | Wheel Tag |
|----------|-----------|
| x86_64 (amd64) | `manylinux_2_28_x86_64` |
| aarch64 (arm64) | `manylinux_2_28_aarch64` |

---

## Usage Examples

### Python API with Batch Processing

```python
from vllm import LLM, SamplingParams

llm = LLM(
    model="microsoft/phi-2",
    device="cpu",
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
    model="mistralai/Mistral-7B-Instruct-v0.2",
    messages=[{"role": "user", "content": "What is the capital of France?"}]
)
print(response.choices[0].message.content)
```

### cURL

```bash
# Chat completion
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "mistralai/Mistral-7B-Instruct-v0.2",
       "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## Performance Tips

### 1. Use TCMalloc (strongly recommended)

TCMalloc provides significantly better memory allocation performance and cache locality:

```bash
# Install TCMalloc
sudo apt install libtcmalloc-minimal4  # Debian/Ubuntu
# or
sudo dnf install gperftools-libs        # RHEL/Fedora

# Find and preload it
export LD_PRELOAD=$(find /usr -name "libtcmalloc_minimal.so*" | head -1)
python -m vllm.entrypoints.openai.api_server --model your-model --device cpu
```

### 2. Set thread count to physical cores

Use physical cores only -- disable hyper-threading for best performance:

```bash
# Check physical cores
lscpu | grep "Core(s) per socket"

export OMP_NUM_THREADS=16    # Set to physical core count
export MKL_NUM_THREADS=16
```

**Tip:** Reserve 1-2 cores for the HTTP serving framework to avoid CPU oversubscription:
```bash
export VLLM_CPU_OMP_THREADS_BIND=0-13    # Bind inference to cores 0-13
export VLLM_CPU_NUM_OF_RESERVED_CPU=2     # Reserve 2 cores for serving
```

### 3. Use BFloat16

Recommended for all CPUs that support it (avoids unstable float16 on CPU):

```python
llm = LLM(model="your-model", device="cpu", dtype="bfloat16")
```

### 4. NUMA optimization for multi-socket systems

On multi-socket systems, avoid cross-NUMA memory access:

```bash
# Simple: bind to one NUMA node
numactl --cpunodebind=0 --membind=0 python your_script.py

# Advanced: use Tensor Parallel across NUMA nodes (e.g., 2-socket)
VLLM_CPU_OMP_THREADS_BIND=0-31|32-63 python -m vllm.entrypoints.openai.api_server \
  --model your-model --device cpu --tensor-parallel-size 2
```

### 5. Set KV cache size

Larger KV cache allows more concurrent requests:

```bash
# Allocate 40 GB for KV cache (default is 0, auto)
export VLLM_CPU_KVCACHE_SPACE=40
```

### 6. Enable SGL kernels (x86 only, experimental)

Small-batch optimized kernels for low-latency online serving:

```bash
export VLLM_CPU_SGL_KERNEL=1
```

### 7. Use quantized models for lower memory

```python
llm = LLM(model="TheBloke/Llama-2-7B-GPTQ", device="cpu", quantization="gptq")
```

### Memory Estimation

| Model Size | dtype | Approximate RAM |
|------------|-------|-----------------|
| 1B params | bfloat16 | ~4 GB |
| 7B params | bfloat16 | ~16 GB |
| 7B params | GPTQ INT4 | ~6 GB |
| 13B params | bfloat16 | ~28 GB |
| 70B params | bfloat16 | ~140 GB |
| 70B params | GPTQ INT4 | ~40 GB |

*Add KV cache overhead: ~2-8 GB depending on `VLLM_CPU_KVCACHE_SPACE` and context length.*

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VLLM_CPU_KVCACHE_SPACE` | KV cache size in GB (larger = more concurrent requests) | 0 (auto) |
| `VLLM_CPU_OMP_THREADS_BIND` | CPU core binding (`0-31`, `auto`, or `nobind`) | auto |
| `VLLM_CPU_NUM_OF_RESERVED_CPU` | Cores reserved for HTTP serving (when bind=auto) | 0 |
| `VLLM_CPU_SGL_KERNEL` | Enable small-batch optimized kernels (x86, experimental) | 0 |
| `OMP_NUM_THREADS` | OpenMP thread count | All cores |
| `MKL_NUM_THREADS` | Intel MKL thread count | All cores |
| `LD_PRELOAD` | Preload TCMalloc for better memory performance | None |
| `HF_TOKEN` | Hugging Face access token | None |
| `HF_HOME` | Hugging Face cache directory | ~/.cache/huggingface |

---

## Supported Models

vLLM supports 100+ models including:

| Category | Models |
|----------|--------|
| **LLMs** | Llama 2/3/3.1/3.2, Mistral, Mixtral, Qwen 2/2.5/3, Phi-2/3/4, Gemma 2/3, DeepSeek V2/V3/R1 |
| **Code** | CodeLlama, DeepSeek-Coder, StarCoder 1/2, CodeGemma, Qwen2.5-Coder |
| **Embedding** | E5-Mistral, GTE, BGE, Nomic-Embed, Jina |
| **Multimodal** | LLaVA, Qwen-VL, Qwen2.5-VL, InternVL, Pixtral, MiniCPM-V |

Full list: [vLLM Supported Models](https://docs.vllm.ai/en/latest/models/supported_models.html)

---

## Framework Integrations

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

### Any OpenAI-compatible client

vLLM's server is fully OpenAI API-compatible. Any client library that supports `base_url` override works out of the box -- including Semantic Kernel, AutoGen, CrewAI, and others.

---

## Version Support

| Version Range | Strategy | Status |
|---------------|----------|--------|
| v0.17.0+ | Unified CPU wheel (this package) | **Active** |
| v0.8.5 -- v0.15.x | Legacy 5-variant wheels | Archived on PyPI |

Legacy variant packages remain on PyPI for older vLLM versions:

| Legacy Package | ISA | PyPI |
|----------------|-----|------|
| `vllm-cpu-avx512` | AVX512 | [pypi.org/project/vllm-cpu-avx512](https://pypi.org/project/vllm-cpu-avx512/) |
| `vllm-cpu-avx512vnni` | AVX512 + VNNI | [pypi.org/project/vllm-cpu-avx512vnni](https://pypi.org/project/vllm-cpu-avx512vnni/) |
| `vllm-cpu-avx512bf16` | AVX512 + BF16 | [pypi.org/project/vllm-cpu-avx512bf16](https://pypi.org/project/vllm-cpu-avx512bf16/) |
| `vllm-cpu-amxbf16` | AVX512 + AMX | [pypi.org/project/vllm-cpu-amxbf16](https://pypi.org/project/vllm-cpu-amxbf16/) |

---

## Troubleshooting

### Illegal Instruction Error

The unified wheel auto-detects CPU capabilities, but if you see this error:

```bash
# Check what your CPU supports
lscpu | grep -E "avx512|vnni|bf16|amx"
```

If no AVX2 flags appear, your CPU is too old for vLLM CPU inference.

### Out of Memory (OOM)

Reduce memory usage by lowering context length and using lower precision:

```python
llm = LLM(model="your-model", device="cpu", max_model_len=2048, dtype="bfloat16")
```

Also reduce KV cache: `export VLLM_CPU_KVCACHE_SPACE=2`

### Slow Performance Checklist

1. **TCMalloc loaded?** Check with `echo $LD_PRELOAD`
2. **Thread count correct?** `echo $OMP_NUM_THREADS` should equal physical core count
3. **Hyper-threading disabled?** Recommended for bare-metal deployments
4. **Cross-NUMA access?** Use `VLLM_CPU_OMP_THREADS_BIND` to pin to one NUMA node
5. **Using bfloat16?** Float16 is unstable on CPU -- always use `dtype="bfloat16"`

### Multiple vLLM Packages Conflict

```bash
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y
pip install vllm-cpu
```

### RuntimeError: Failed to infer device type

For legacy versions (v0.8.5--v0.15.x), use `.post2` releases which include the CPU platform fix:

```bash
pip install vllm-cpu==0.12.0.post2
```

---

## Links & Resources

| Resource | Link |
|----------|------|
| **GitHub Repository** | [github.com/MekayelAnik/vllm-cpu](https://github.com/MekayelAnik/vllm-cpu) |
| **Docker Images** | [hub.docker.com/r/mekayelanik/vllm-cpu](https://hub.docker.com/r/mekayelanik/vllm-cpu) |
| **vLLM Documentation** | [docs.vllm.ai](https://docs.vllm.ai/en/latest/) |
| **Upstream vLLM** | [github.com/vllm-project/vllm](https://github.com/vllm-project/vllm) |
| **Report Issues** | [github.com/MekayelAnik/vllm-cpu/issues](https://github.com/MekayelAnik/vllm-cpu/issues) |
| **Changelog** | [GitHub Releases](https://github.com/MekayelAnik/vllm-cpu/releases) |

---

## License

- **This project:** [GPL-3.0](https://github.com/MekayelAnik/vllm-cpu/blob/main/LICENSE)
- **Upstream vLLM:** [Apache-2.0](https://github.com/vllm-project/vllm/blob/main/LICENSE)
