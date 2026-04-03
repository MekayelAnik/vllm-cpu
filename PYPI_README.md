![PyPI - Version](https://img.shields.io/pypi/v/vllm-cpu?logo=pypi&logoColor=white&label=PyPI)
![PyPI - Downloads](https://img.shields.io/pypi/dm/vllm-cpu?logo=pypi&logoColor=white&label=Downloads)
![PyPI - Python Version](https://img.shields.io/pypi/pyversions/vllm-cpu?logo=python&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-x86__64%20%7C%20aarch64-green)
![License](https://img.shields.io/github/license/MekayelAnik/vllm-cpu)

# vllm-cpu

Unified CPU wheels for [vLLM](https://github.com/vllm-project/vllm) — the fast and easy-to-use library for LLM inference and serving.

---

## Why vllm-cpu?

The upstream vLLM project publishes CPU wheels only on GitHub Releases with a `+cpu` local version suffix, which **cannot be uploaded to PyPI**. This package solves that:

| Feature | Upstream (`vllm`) | This package (`vllm-cpu`) |
|---------|-------------------|---------------------------|
| Install | Manual URL from GitHub Releases | `pip install vllm-cpu` |
| PyPI | Not available (PEP 440 blocks `+cpu`) | Available |
| glibc | `manylinux_2_35` (Ubuntu 22.04+) | `manylinux_2_28` (Debian 10+, Ubuntu 18.04+) |
| ISA detection | Runtime auto-detect | Runtime auto-detect (same) |

## Install

```bash
# Latest
pip install vllm-cpu

# Specific version
pip install vllm-cpu==0.17.0
```

## Quick Start

### Python API

```python
from vllm import LLM, SamplingParams

llm = LLM(model="facebook/opt-125m", device="cpu")
output = llm.generate("The future of AI is", SamplingParams(temperature=0.8, max_tokens=128))
print(output[0].outputs[0].text)
```

### OpenAI-compatible API server

```bash
vllm serve facebook/opt-125m --device cpu --dtype auto
```

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "facebook/opt-125m", "prompt": "The future of AI is", "max_tokens": 128}'
```

## Requirements

- **Python**: 3.8+ (stable ABI, one wheel for all versions)
- **OS**: Linux (glibc 2.28+) -- Debian 10+, Ubuntu 18.04+, RHEL 8+, Amazon Linux 2023+
- **CPU**: x86_64 with AVX2 (minimum) or AVX512 (optimal), or aarch64

## Supported CPU Instructions

The unified wheel automatically detects and uses the best available instruction set at import time:

| CPU Feature | Support |
|-------------|---------|
| AVX2 | Baseline (all x86_64) |
| AVX512 | Optimal performance |
| AVX512-VNNI | INT8 acceleration |
| AVX512-BF16 | BFloat16 native ops |
| AMX-BF16 | Matrix acceleration (Sapphire Rapids+) |
| aarch64 NEON | ARM baseline |

No configuration needed -- the correct binary is loaded automatically at `import vllm`.

## Supported Platforms

| Platform | Wheel Tag |
|----------|-----------|
| x86_64 (amd64) | `manylinux_2_28_x86_64` |
| aarch64 (arm64) | `manylinux_2_28_aarch64` |

## How It Works

Starting with v0.17.0, vLLM ships a **unified CPU wheel** containing both AVX2 and AVX512 code paths:

1. The wheel includes `_C.so` (AVX512+BF16+VNNI+AMX) and `_C_AVX2.so` (AVX2 fallback)
2. At import time, `vllm/platforms/cpu.py` checks CPU capabilities via PyTorch
3. The correct `.so` is loaded once -- zero runtime dispatch overhead

### Stable ABI (cp38-abi3)

The wheels use Python's [stable ABI](https://docs.python.org/3/c-api/stable.html), meaning **one wheel works with Python 3.8+**. No per-Python-version builds needed.

## Version Support

| Version Range | Strategy | Status |
|---------------|----------|--------|
| v0.17.0+ | Unified CPU wheel | **Active** |
| v0.8.5 -- v0.15.x | Legacy 5-variant wheels | Archived on PyPI |

Legacy variant packages (`vllm-cpu-avx512`, `vllm-cpu-avx512vnni`, `vllm-cpu-avx512bf16`, `vllm-cpu-amxbf16`) remain available on PyPI for older vLLM versions but are no longer updated.

## Links

- [GitHub Repository](https://github.com/MekayelAnik/vllm-cpu)
- [Docker Images](https://github.com/MekayelAnik/vllm-cpu#docker-usage)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Report Issues](https://github.com/MekayelAnik/vllm-cpu/issues)
- [Changelog](https://github.com/MekayelAnik/vllm-cpu/releases)

## License

Apache 2.0 -- same as [vLLM](https://github.com/vllm-project/vllm/blob/main/LICENSE).
