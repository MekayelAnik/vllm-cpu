# Installation Guide

## For End Users

### ✅ Zero Configuration Installation

**All dependencies are automatically installed!** You don't need to manually install PyTorch, transformers, or any other dependencies.

```bash
# Just install the wheel - that's it!
pip install vllm-cpu-avx512bf16

# Or from a downloaded wheel
pip install vllm_cpu_avx512bf16-*.whl

# Everything is ready to use immediately
python -c "from vllm import LLM; print('Ready to go!')"
```

### What Gets Installed Automatically

When you install any `vllm-cpu-*` package, pip automatically installs:

- ✅ **PyTorch 2.8.0** (CPU version)
- ✅ **Intel Extension for PyTorch (IPEX)** 2.8.0 (x86_64 only)
- ✅ **Transformers** 4.56.0+
- ✅ **FastAPI**, **Uvicorn** (for serving)
- ✅ **NumPy**, **Pydantic**, **Pillow**
- ✅ **All other vLLM dependencies**

**No manual dependency installation required!**

### Choosing the Right Package

| Package | Install Command | For CPUs |
|---------|----------------|----------|
| `vllm-cpu` | `pip install vllm-cpu` | All CPUs (baseline) |
| `vllm-cpu-avx512` | `pip install vllm-cpu-avx512` | Intel Skylake-X+ |
| `vllm-cpu-avx512vnni` | `pip install vllm-cpu-avx512vnni` | Intel Cascade Lake+ |
| `vllm-cpu-avx512bf16` | `pip install vllm-cpu-avx512bf16` | Intel Cooper Lake+ |
| `vllm-cpu-amxbf16` | `pip install vllm-cpu-amxbf16` | Intel Sapphire Rapids+ |

### Quick Start

```bash
# 1. Check your CPU
lscpu | grep -i "avx512\|vnni\|amx"

# 2. Install appropriate package
pip install vllm-cpu-avx512bf16  # Example for Ice Lake/Tiger Lake

# 3. Start using immediately
python << EOF
from vllm import LLM

llm = LLM(model="facebook/opt-125m", device="cpu")
output = llm.generate("Hello, my name is", max_tokens=20)
print(output[0].outputs[0].text)
EOF
```

## For Builders/Developers

### System Dependencies (Build Time Only)

These are **only needed for building wheels**, not for using them:

```bash
# Debian/Ubuntu
sudo apt-get install -y \
    gcc-14 g++-14 \
    cmake ninja-build \
    ccache \
    libtcmalloc-minimal4 \
    libnuma-dev \
    numactl \
    jq \
    git

# Install uv package manager
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Building Wheels

```bash
# Clone this repository
git clone <your-repo-url>
cd vllm-cpu

# Install Python build tools
pip install -e ".[dev]"

# Build all variants (includes all dependencies in the wheels)
./build_wheels.sh

# Output in ./dist/
ls -lh dist/*.whl
```

### Testing Built Wheels

```bash
# Install the wheel (all dependencies install automatically)
pip install dist/vllm_cpu_avx512bf16-*.whl

# Test immediately - no additional setup
python -c "import vllm; print(vllm.__version__)"
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import transformers; print(f'Transformers: {transformers.__version__}')"
```

## Common Questions

### Q: Do I need to install PyTorch separately?

**A: No!** PyTorch (CPU version) is automatically installed as a dependency.

### Q: Do I need to install transformers, fastapi, or other libraries?

**A: No!** All dependencies are included in the wheel and install automatically.

### Q: What about Intel OpenMP or IPEX?

**A: Included!** For x86_64 builds, Intel OpenMP and IPEX are automatically installed.

### Q: Can I install multiple variants?

**A: No, don't do that.** Installing multiple variants will conflict. Uninstall the old one first:

```bash
pip uninstall vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y
pip install vllm-cpu-avx512bf16  # Install the one you want
```

### Q: How do I verify which package I have installed?

```bash
pip list | grep vllm
```

## Troubleshooting

### Import Error: "No module named 'vllm'"

Make sure you activated your virtual environment (if using one):

```bash
source venv/bin/activate  # Linux/Mac
pip install vllm-cpu-avx512bf16
```

### Wrong Dependencies Installed

Make sure you don't have conflicting vLLM packages:

```bash
# Uninstall all vllm packages
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y

# Reinstall the correct one
pip install vllm-cpu-avx512bf16
```

### PyTorch Version Conflict

The wheels depend on specific PyTorch versions. If you have a different PyTorch installed:

```bash
# Uninstall existing PyTorch
pip uninstall torch torchvision torchaudio -y

# Install the vLLM package (will install correct PyTorch)
pip install vllm-cpu-avx512bf16
```

## Summary

**For end users**: Just `pip install vllm-cpu-<variant>` - everything else is automatic!

**For builders**: System dependencies needed only for building, not for using the wheels.

The wheels are self-contained with all Python dependencies included!
