# PyTorch CPU-Only Dependency Configuration

## Overview

vLLM CPU wheels are configured to use PyTorch CPU-only versions, which significantly reduces installation size and avoids unnecessary CUDA dependencies.

## Why CPU-Only PyTorch?

### Size Comparison

| PyTorch Version | Size | CUDA |
|----------------|------|------|
| Standard PyPI | ~2.5GB | ✅ Included |
| CPU-only | ~200MB | ❌ Not included |

**Savings**: ~2.3GB per installation

### Benefits

✅ **Smaller downloads** - 12x smaller than CUDA version
✅ **Faster installation** - Less data to download and extract
✅ **No CUDA dependencies** - Works on systems without GPUs
✅ **Simpler deployment** - Fewer system requirements
✅ **Lower storage** - Significant disk space savings

## Installation Instructions

### For End Users

When installing vLLM CPU wheels, PyTorch with vision and audio support should be installed from the CPU-only index:

```bash
# Step 1: Install PyTorch CPU-only version with torchvision and torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Step 2: Install vLLM CPU wheel
pip install vllm-cpu
```

**Why torchvision and torchaudio?**
- `torchvision`: Required for vision-language models (phi3v, qwen-vl, internvl, etc.)
- `torchaudio`: Required for audio models (minicpm-o-2_6, etc.)

### One-Line Installation

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && pip install vllm-cpu
```

### For Specific Variants

```bash
# AVX512 variant
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && pip install vllm-cpu-avx512

# AVX512VNNI variant
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && pip install vllm-cpu-avx512vnni

# AVX512BF16 variant
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && pip install vllm-cpu-avx512bf16

# AMXBF16 variant
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && pip install vllm-cpu-amxbf16
```

## Build Configuration

### During Build

The build script (`build_wheels.sh`) automatically installs PyTorch CPU-only version with vision and audio support:

```bash
# In build environment
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

This ensures:
- vLLM is built against CPU-only PyTorch
- Vision models (torchvision) work correctly
- Audio models (torchaudio) work correctly
- No CUDA compilation required
- Consistent environment

### In pyproject.toml

The build script adds installation instructions to the wheel's metadata:

```toml
# vLLM CPU wheels require PyTorch CPU-only version with vision and audio support
# Users should install PyTorch before installing this package:
# pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
#
# Note: torchvision is required for vision-language models (phi3v, minicpm, qwen-vl, etc.)
#       torchaudio is required for audio models (minicpm-o-2_6, etc.)
#       The standard PyPI PyTorch includes CUDA dependencies which are not needed
#       for CPU-only inference. Using the CPU-only index reduces installation size significantly.
```

## Verification

### Check PyTorch Installation

```bash
python -c "import torch; print(f'PyTorch {torch.__version__}')"
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

**Expected output**:
```
PyTorch 2.1.0+cpu
CUDA available: False
```

### Check vLLM Integration

```bash
python -c "import vllm; import torch; print(f'vLLM {vllm.__version__} with PyTorch {torch.__version__}')"
```

**Expected output**:
```
vLLM 0.6.3 with PyTorch 2.1.0+cpu
```

## Troubleshooting

### Issue 1: CUDA PyTorch Installed

**Symptom**:
```bash
python -c "import torch; print(torch.__version__)"
# Output: 2.1.0+cu118  (CUDA version)
```

**Problem**: Standard PyPI PyTorch installed instead of CPU-only

**Solution**:
```bash
# Uninstall CUDA version
pip uninstall torch torchvision

# Install CPU-only version
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
```

### Issue 2: Large Installation Size

**Symptom**: Installation takes >2GB

**Problem**: CUDA PyTorch dependencies included

**Solution**: Reinstall with CPU-only PyTorch (see Issue 1)

### Issue 3: PyTorch Version Mismatch

**Symptom**:
```
ImportError: vLLM requires PyTorch >= 2.0.0
```

**Solution**:
```bash
# Install specific PyTorch version
pip install torch==2.1.0 torchvision==0.16.0 --index-url https://download.pytorch.org/whl/cpu
```

### Issue 4: Index URL Not Working

**Symptom**:
```
ERROR: Could not find a version that satisfies the requirement torch
```

**Problem**: Network issues or index unavailable

**Solution**:
```bash
# Try with pip upgrade
pip install --upgrade pip

# Retry with full URL
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Or use alternative index
pip install torch torchvision --extra-index-url https://download.pytorch.org/whl/cpu
```

## requirements.txt Example

For projects using vLLM CPU:

```txt
# requirements.txt

# Install PyTorch CPU-only first
--index-url https://download.pytorch.org/whl/cpu
torch>=2.1.0
torchvision>=0.16.0

# Then install vLLM CPU
--index-url https://pypi.org/simple
vllm-cpu>=0.6.3
```

## Docker Example

```dockerfile
FROM python:3.13-slim

# Install PyTorch CPU-only
RUN pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install vLLM CPU
RUN pip install vllm-cpu

# Verify installation
RUN python -c "import torch; assert not torch.cuda.is_available()"
RUN python -c "import vllm; print(vllm.__version__)"

CMD ["python"]
```

## GitHub Actions Example

```yaml
name: Test vLLM CPU

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.13'

      - name: Install PyTorch CPU
        run: |
          pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

      - name: Install vLLM CPU
        run: |
          pip install vllm-cpu

      - name: Verify installation
        run: |
          python -c "import torch; print(f'PyTorch: {torch.__version__}')"
          python -c "import torch; assert not torch.cuda.is_available()"
          python -c "import vllm; print(f'vLLM: {vllm.__version__}')"
```

## pip.conf Configuration

For system-wide CPU-only PyTorch:

```ini
# ~/.pip/pip.conf (Linux/macOS)
# %APPDATA%\pip\pip.ini (Windows)

[global]
extra-index-url = https://download.pytorch.org/whl/cpu
```

This allows:
```bash
pip install torch torchvision  # Automatically uses CPU index
pip install vllm-cpu
```

## Poetry Example

```toml
# pyproject.toml

[[tool.poetry.source]]
name = "pytorch-cpu"
url = "https://download.pytorch.org/whl/cpu"
priority = "explicit"

[tool.poetry.dependencies]
python = "^3.9"
torch = {version = "^2.1.0", source = "pytorch-cpu"}
torchvision = {version = "^0.16.0", source = "pytorch-cpu"}
vllm-cpu = "^0.6.3"
```

## Conda Example

```bash
# Create environment
conda create -n vllm-cpu python=3.13

# Activate
conda activate vllm-cpu

# Install PyTorch CPU from conda
conda install pytorch torchvision cpuonly -c pytorch

# Install vLLM CPU from pip
pip install vllm-cpu
```

## PyTorch Version Compatibility

| vLLM Version | Minimum PyTorch | Recommended PyTorch |
|--------------|----------------|---------------------|
| 0.6.x | 2.0.0 | 2.1.0+cpu |
| 0.5.x | 1.13.0 | 2.0.1+cpu |
| 0.4.x | 1.13.0 | 1.13.1+cpu |

## Best Practices

### DO ✅

- Install PyTorch CPU-only before vLLM CPU
- Use `--index-url https://download.pytorch.org/whl/cpu`
- Verify PyTorch is CPU-only after installation
- Pin PyTorch versions in requirements.txt
- Document PyTorch installation in project README

### DON'T ❌

- Don't install standard PyPI PyTorch with vLLM CPU
- Don't mix CUDA and CPU-only PyTorch
- Don't assume PyTorch is bundled (it's not)
- Don't skip PyTorch installation verification
- Don't use CUDA PyTorch on CPU-only systems

## FAQ

### Q: Why isn't PyTorch bundled with vLLM CPU wheels?

**A**: PyTorch is large (~200MB for CPU-only, ~2.5GB for CUDA). Bundling it would:
- Increase wheel size 10x
- Cause conflicts with user's PyTorch version
- Prevent using custom PyTorch builds
- Violate Python packaging best practices

### Q: Can I use CUDA PyTorch with vLLM CPU?

**A**: Not recommended. vLLM CPU is optimized for CPU inference and doesn't benefit from CUDA PyTorch. You'll waste 2GB+ on unused CUDA libraries.

### Q: What if I already have PyTorch installed?

**A**: Check if it's CPU-only:
```bash
python -c "import torch; print(torch.__version__)"
```
If it shows `+cu***` (e.g., `+cu118`), reinstall CPU-only version.

### Q: Can I install from requirements.txt in one command?

**A**: Yes, see the requirements.txt example above. The key is using `--index-url` before torch.

### Q: Does this work on ARM/M1/M2 Macs?

**A**: Yes, PyTorch CPU-only works on Apple Silicon. Use:
```bash
pip install torch torchvision
pip install vllm-cpu
```

## Summary

**Key Points**:

✅ **Install PyTorch CPU-only first**: Use `--index-url https://download.pytorch.org/whl/cpu`
✅ **Verify installation**: Check `torch.__version__` shows `+cpu`
✅ **Saves 2GB+**: CPU-only vs CUDA version
✅ **Works everywhere**: No GPU required
✅ **Documented in wheel**: Instructions included in metadata

**Installation Command**:
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && pip install vllm-cpu
```

**What gets installed**:
- `torch` (~200MB): Core PyTorch CPU-only
- `torchvision` (~7MB): Vision models support (phi3v, qwen-vl, internvl, etc.)
- `torchaudio` (~3MB): Audio models support (minicpm-o-2_6, etc.)

---

**Version**: 1.0.0
**Date**: 2025-11-21
**Status**: ✅ Implemented
