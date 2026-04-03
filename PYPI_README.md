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

1. **Set thread count** to physical cores (not threads):
   ```bash
   export OMP_NUM_THREADS=16
   export MKL_NUM_THREADS=16
   ```

2. **Use BFloat16** on supported CPUs:
   ```python
   llm = LLM(model="your-model", device="cpu", dtype="bfloat16")
   ```

3. **NUMA awareness** for multi-socket systems:
   ```bash
   numactl --cpunodebind=0 --membind=0 python your_script.py
   ```

4. **Use quantized models** for lower memory:
   ```python
   llm = LLM(model="TheBloke/Llama-2-7B-GPTQ", device="cpu", quantization="gptq")
   ```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OMP_NUM_THREADS` | OpenMP thread count | All cores |
| `MKL_NUM_THREADS` | Intel MKL thread count | All cores |
| `VLLM_CPU_KVCACHE_SPACE` | KV cache size in GB | 4 |
| `VLLM_CPU_OMP_THREADS_BIND` | Thread binding strategy | auto |
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

Your CPU doesn't support the instruction set the loaded `.so` requires. This should not happen with the unified wheel (it auto-detects), but if it does:

```bash
# Check what your CPU supports
lscpu | grep -E "avx512|vnni|bf16|amx"
```

### Out of Memory

```python
llm = LLM(model="your-model", device="cpu", max_model_len=2048, dtype="bfloat16")
```

### Multiple vLLM Packages Conflict

```bash
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y
pip install vllm-cpu
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
