# Quick Start: Publishing vLLM CPU Builds to PyPI

This is a condensed guide to get you started quickly. For full details, see [PYPI_PUBLISHING_GUIDE.md](PYPI_PUBLISHING_GUIDE.md).

## 1. Initial Setup (One Time)

### Install Dependencies

```bash
# System dependencies
sudo apt-get update && sudo apt-get install -y \
    gcc-14 g++-14 cmake ninja-build ccache \
    libtcmalloc-minimal4 libnuma-dev numactl jq git

# uv package manager
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Python tools
pip install build twine setuptools wheel
```

### Configure PyPI Credentials

```bash
# Create .env file with your PyPI tokens
cat > .env << 'EOF'
PYPI_API_TOKEN=pypi-YOUR_TOKEN_HERE
TEST_PYPI_API_TOKEN=pypi-YOUR_TEST_TOKEN_HERE
EOF

chmod 600 .env
```

Get tokens from:
- PyPI: https://pypi.org/manage/account/token/
- Test PyPI: https://test.pypi.org/manage/account/token/

## 2. Build Wheels

### Build All Variants (2-5 hours)

```bash
./build_wheels.sh
```

This builds 5 packages:
- `vllm-cpu` (base, no AVX512)
- `vllm-cpu-avx512`
- `vllm-cpu-avx512vnni`
- `vllm-cpu-avx512bf16`
- `vllm-cpu-amxbf16`

### Build Single Variant (30-60 minutes)

```bash
./build_wheels.sh --variant=vllm-cpu-avx512bf16
```

### Check Build Output

```bash
ls -lh dist/
# Should show .whl files for each variant
```

## 3. Test Build

### Test Locally

```bash
# Install wheel
pip install dist/vllm_cpu_avx512bf16-*.whl

# Test import
python -c "import vllm; print(vllm.__version__)"

# Test inference
python << 'EOF'
from vllm import LLM

llm = LLM(model="facebook/opt-125m", device="cpu")
output = llm.generate("Hello, my name is")
print(output)
EOF
```

## 4. Publish to Test PyPI (Recommended First)

```bash
# Publish to Test PyPI
./publish_to_pypi.sh --test

# Test installation from Test PyPI
pip install --index-url https://test.pypi.org/simple/ vllm-cpu-avx512bf16
```

## 5. Publish to PyPI

```bash
# Publish to production PyPI
./publish_to_pypi.sh

# This publishes all wheels in ./dist/
```

## 6. Publish CPU Detector Tool

```bash
cd cpu_detect

# Build
python -m build

# Publish to PyPI
twine upload dist/* --username __token__ --password $PYPI_API_TOKEN
```

## 7. Verify Installation

```bash
# Install CPU detector
pip install vllm-cpu-detect

# Detect CPU and get recommendation
vllm-cpu-detect

# Install recommended package
pip install vllm-cpu-amxbf16  # Use whatever is recommended
```

## Quick Command Reference

```bash
# Build all variants
./build_wheels.sh

# Build specific variant
./build_wheels.sh --variant=vllm-cpu-avx512bf16

# Publish to Test PyPI
./publish_to_pypi.sh --test

# Publish to PyPI
./publish_to_pypi.sh

# Publish without rebuilding
./publish_to_pypi.sh --skip-build

# Publish single variant
./publish_to_pypi.sh --variant=vllm-cpu-amxbf16
```

## GitHub Actions (Automated)

### Setup

1. Add secrets to GitHub:
   - `PYPI_API_TOKEN`
   - `TEST_PYPI_API_TOKEN`

2. Push version tag:
```bash
git tag v0.11.2
git push origin v0.11.2
```

3. Workflow automatically builds and publishes all variants!

## Common Issues

### Build Out of Memory

```bash
./build_wheels.sh --max-jobs=2
```

### Build Takes Too Long

```bash
# Build one variant at a time
for variant in vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16; do
    ./build_wheels.sh --variant=$variant
done
```

### Wrong Package Installed

```bash
# Uninstall all vllm packages
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y

# Use CPU detector
vllm-cpu-detect
pip install vllm-cpu-amxbf16  # Example
```

## Next Steps

- Read full guide: [PYPI_PUBLISHING_GUIDE.md](PYPI_PUBLISHING_GUIDE.md)
- Set up CI/CD: See `.github/workflows/build-and-publish.yml`
- Monitor upstream: https://github.com/vllm-project/vllm/releases

## Package Comparison

| Package | Best For |
|---------|----------|
| `vllm-cpu` | Older CPUs, ARM64 |
| `vllm-cpu-avx512` | Intel Skylake-X, Cascade Lake |
| `vllm-cpu-avx512vnni` | Intel Cascade Lake, Ice Lake |
| `vllm-cpu-avx512bf16` | Intel Cooper Lake, Ice Lake, Tiger Lake |
| `vllm-cpu-amxbf16` | Intel Sapphire Rapids (4th gen Xeon)+ |

**Not sure?** Use `vllm-cpu-detect` to find out!
