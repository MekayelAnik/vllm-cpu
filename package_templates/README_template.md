# {PACKAGE_NAME}

{DESCRIPTION}

This is a CPU-optimized build of vLLM with support for {ISA_FEATURES}.

## Installation

```bash
pip install {PACKAGE_NAME}
```

## CPU Requirements

This build requires a CPU with the following instruction set extensions:

{CPU_REQUIREMENTS}

## Quick Start

```python
from vllm import LLM, SamplingParams

# Initialize the model
llm = LLM(
    model="facebook/opt-125m",
    device="cpu",
    max_num_seqs=1
)

# Generate text
prompts = ["Hello, my name is"]
sampling_params = SamplingParams(temperature=0.8, top_p=0.95)
outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    print(f"Generated text: {output.outputs[0].text}")
```

## Environment Variables

The following environment variables are automatically set for this build:

- `VLLM_TARGET_DEVICE=cpu`
{ENV_VARS}

## Performance Optimization

For best performance on x86_64 CPUs:

```bash
# Install tcmalloc
apt-get install libtcmalloc-minimal4

# Set LD_PRELOAD
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
```

## Choosing the Right Build

Not sure which build to install? Use our CPU detection helper:

```bash
pip install vllm-cpu-detect
vllm-cpu-detect
```

Or manually check your CPU features:

```bash
# On Linux
lscpu | grep -i flags
cat /proc/cpuinfo | grep flags | head -n 1
```

## Available Builds

| Package | AVX512 | VNNI | BF16 | AMX | Platforms |
|---------|--------|------|------|-----|-----------|
| `vllm-cpu` | ❌ | ❌ | ❌ | ❌ | x86_64, ARM64 |
| `vllm-cpu-avx512` | ✅ | ❌ | ❌ | ❌ | x86_64 |
| `vllm-cpu-avx512vnni` | ✅ | ✅ | ❌ | ❌ | x86_64 |
| `vllm-cpu-avx512bf16` | ✅ | ✅ | ✅ | ❌ | x86_64 |
| `vllm-cpu-amxbf16` | ✅ | ✅ | ✅ | ✅ | x86_64 |

### CPU Compatibility Guide

- **vllm-cpu**: Compatible with all CPUs (x86_64 and ARM64), best for older CPUs or ARM processors
- **vllm-cpu-avx512**: Intel Skylake-X/W, Cascade Lake, Ice Lake, Tiger Lake and newer
- **vllm-cpu-avx512vnni**: Intel Cascade Lake, Ice Lake, Tiger Lake, Rocket Lake and newer
- **vllm-cpu-avx512bf16**: Intel Cooper Lake, Ice Lake, Tiger Lake, Rocket Lake and newer
- **vllm-cpu-amxbf16**: Intel Sapphire Rapids (4th gen Xeon), Emerald Rapids (5th gen Xeon) and newer

## Documentation

Full documentation available at: https://docs.vllm.ai/

## License

Apache License 2.0

## Upstream

This package is built from the official vLLM project: https://github.com/vllm-project/vllm

Version: {VLLM_VERSION}
