# PyPI Publishing Guide for vLLM CPU Builds

This guide explains how to build and publish CPU-optimized vLLM packages to PyPI.

## Overview

This project publishes **5 separate packages** to PyPI, each optimized for different CPU instruction sets:

| Package | AVX512 | VNNI | BF16 | AMX | Platforms | Target CPUs |
|---------|--------|------|------|-----|-----------|-------------|
| `vllm-cpu` | ❌ | ❌ | ❌ | ❌ | x86_64, ARM64 | All CPUs |
| `vllm-cpu-avx512` | ✅ | ❌ | ❌ | ❌ | x86_64 | Intel Skylake-X+ |
| `vllm-cpu-avx512vnni` | ✅ | ✅ | ❌ | ❌ | x86_64 | Intel Cascade Lake+ |
| `vllm-cpu-avx512bf16` | ✅ | ✅ | ✅ | ❌ | x86_64 | Intel Cooper Lake+ |
| `vllm-cpu-amxbf16` | ✅ | ✅ | ✅ | ✅ | x86_64 | Intel Sapphire Rapids+ |

Additionally, we publish:
- `vllm-cpu-detect`: A CPU detection tool that recommends the optimal package

## Prerequisites

### System Requirements

- **OS**: Debian Trixie (or compatible Linux distribution)
- **Python**: 3.9 or later (3.13 recommended)
- **Memory**: 32GB+ RAM recommended for building
- **Disk**: 50GB+ free space

### Required Tools

```bash
# Install system dependencies
sudo apt-get update
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

# Install Python build tools
pip install build twine setuptools wheel
```

## Project Structure

```
vllm-cpu/
├── build_config.json                 # Build configuration for all variants
├── build_wheels.sh                   # Main build script
├── publish_to_pypi.sh                # PyPI publishing script
├── generate_package_metadata.py      # Generate package metadata
├── package_templates/                # Templates for README, etc.
│   └── README_template.md
├── package_metadata/                 # Generated metadata (gitignored)
│   ├── vllm-cpu/
│   ├── vllm-cpu-avx512/
│   └── ...
├── cpu_detect/                       # CPU detection tool
│   ├── vllm_cpu_detect.py
│   ├── setup.py
│   └── README.md
├── .github/workflows/
│   └── build-and-publish.yml         # CI/CD workflow
└── resources/
    ├── pypi-builder.sh                # vLLM installation script
    ├── common.txt                     # Common dependencies
    ├── cpu.txt                        # CPU runtime dependencies
    └── cpu-build.txt                  # Build dependencies
```

## Building Wheels

### Build All Variants

```bash
# Build all 5 variants
./build_wheels.sh

# Output will be in ./dist/
ls -lh dist/
```

### Build Specific Variant

```bash
# Build only the AVX512BF16 variant
./build_wheels.sh --variant=vllm-cpu-avx512bf16

# Build with custom options
./build_wheels.sh \
    --variant=vllm-cpu-amxbf16 \
    --vllm-version=0.11.2 \
    --python-version=3.13 \
    --output-dir=./wheels \
    --max-jobs=8
```

### Build Options

- `--variant=NAME`: Build specific variant (default: all)
- `--vllm-version=VERSION`: vLLM version to build (default: latest from git)
- `--python-version=3.13`: Python version (default: 3.13)
- `--output-dir=PATH`: Output directory (default: ./dist)
- `--max-jobs=N`: Parallel build jobs (default: CPU count)
- `--no-cleanup`: Skip cleanup after build

### Build Times

Expected build times on a modern build machine:

- **Per variant**: 30-60 minutes
- **All 5 variants**: 2.5-5 hours

## Package Metadata

### Generate Metadata

Before the first build, generate package metadata:

```bash
# Generate README.md, pyproject.toml for each variant
python generate_package_metadata.py

# Check generated files
ls -R package_metadata/
```

### Customize Metadata

Edit `build_config.json` to customize:
- Package descriptions
- Keywords
- CPU feature flags
- Platform support

Example:

```json
{
  "builds": {
    "vllm-cpu-avx512bf16": {
      "description": "vLLM CPU inference engine (AVX512 + VNNI + BF16 optimized)",
      "package_name": "vllm-cpu-avx512bf16",
      "flags": {
        "disable_avx512": false,
        "enable_avx512vnni": true,
        "enable_avx512bf16": true,
        "enable_amxbf16": false
      },
      "platforms": ["x86_64"],
      "keywords": ["vllm", "llm", "inference", "cpu", "avx512", "vnni", "bf16"]
    }
  }
}
```

## Publishing to PyPI

### Setup PyPI Credentials

1. Create PyPI account at https://pypi.org
2. Create API token at https://pypi.org/manage/account/token/
3. Create Test PyPI token at https://test.pypi.org/manage/account/token/

4. Store tokens in `.env` file:

```bash
cat > .env << 'EOF'
PYPI_API_TOKEN=pypi-AgEIcHlwaS5vcmcC...
TEST_PYPI_API_TOKEN=pypi-AgENdGVzdC5weXBpLm9yZwI...
EOF

chmod 600 .env
```

### Publish to Test PyPI (Recommended First)

```bash
# Build and publish to Test PyPI
./publish_to_pypi.sh --test

# Test installation from Test PyPI
pip install --index-url https://test.pypi.org/simple/ vllm-cpu-avx512
```

### Publish to PyPI

```bash
# Build and publish all variants to PyPI
./publish_to_pypi.sh

# Or publish specific variant
./publish_to_pypi.sh --variant=vllm-cpu-avx512bf16

# Or publish existing wheels without rebuilding
./publish_to_pypi.sh --skip-build --dist-dir=./dist
```

### Publishing Options

- `--test`: Publish to Test PyPI instead of PyPI
- `--dist-dir=PATH`: Directory containing wheels (default: ./dist)
- `--skip-build`: Skip building, just publish existing wheels
- `--variant=NAME`: Only publish specific variant

## CI/CD Automation

### GitHub Actions Workflow

The project includes a GitHub Actions workflow that automatically builds and publishes wheels.

#### Setup GitHub Secrets

1. Go to GitHub repository → Settings → Secrets → Actions
2. Add secrets:
   - `PYPI_API_TOKEN`: Your PyPI API token
   - `TEST_PYPI_API_TOKEN`: Your Test PyPI API token

#### Manual Trigger

```bash
# Trigger workflow manually via GitHub UI:
# Actions → Build and Publish vLLM CPU Wheels → Run workflow

# Or via GitHub CLI:
gh workflow run build-and-publish.yml \
    -f vllm_version=v0.11.2 \
    -f publish_to_pypi=true \
    -f publish_to_test_pypi=false
```

#### Automatic Trigger

The workflow automatically triggers when you push a version tag:

```bash
# Tag a new version
git tag v0.11.2
git push origin v0.11.2

# Workflow will automatically:
# 1. Build all 5 variants
# 2. Publish to PyPI (for stable releases)
# 3. Publish to Test PyPI (for alpha/beta releases)
```

## Version Management

### Version Synchronization

All packages use the **same version number** as the upstream vLLM release:

- **Upstream vLLM**: `0.11.2`
- **Your packages**: `0.11.2` (all 5 variants)

### Release Process

1. **Monitor upstream vLLM releases**: https://github.com/vllm-project/vllm/releases

2. **Build new version**:
```bash
./build_wheels.sh --vllm-version=0.11.2
```

3. **Test locally**:
```bash
pip install dist/vllm_cpu-0.11.2-*.whl
python -c "import vllm; print(vllm.__version__)"
```

4. **Publish to Test PyPI**:
```bash
./publish_to_pypi.sh --test
```

5. **Test installation from Test PyPI**:
```bash
pip install --index-url https://test.pypi.org/simple/ vllm-cpu
```

6. **Publish to PyPI**:
```bash
./publish_to_pypi.sh
```

7. **Tag release**:
```bash
git tag v0.11.2
git push origin v0.11.2
```

## CPU Detection Tool

### Build CPU Detector

```bash
cd cpu_detect
python -m build
ls dist/
```

### Publish CPU Detector

```bash
cd cpu_detect
twine upload dist/* --username __token__ --password $PYPI_API_TOKEN
```

### Test CPU Detector

```bash
pip install vllm-cpu-detect
vllm-cpu-detect
```

## User Installation

**All dependencies install automatically** - users just need to install the wheel!

### Automatic Detection (Recommended)

```bash
# Install CPU detection tool
pip install vllm-cpu-detect

# Detect CPU and get recommendation
vllm-cpu-detect

# Install recommended package (all dependencies auto-installed)
pip install vllm-cpu-amxbf16  # Example output
```

### Manual Installation

```bash
# Check CPU features
lscpu | grep -i flags

# Install appropriate package (all dependencies auto-installed)
pip install vllm-cpu-avx512bf16

# That's it! PyTorch, transformers, etc. install automatically
```

### Verification

```python
import vllm
print(f"vLLM version: {vllm.__version__}")

# Check CPU optimizations
import os
print(f"AVX512 disabled: {os.getenv('VLLM_CPU_DISABLE_AVX512', '0')}")
print(f"VNNI enabled: {os.getenv('VLLM_CPU_AVX512VNNI', '0')}")
print(f"BF16 enabled: {os.getenv('VLLM_CPU_AVX512BF16', '0')}")
print(f"AMX enabled: {os.getenv('VLLM_CPU_AMXBF16', '0')}")
```

## Troubleshooting

### Build Failures

#### Out of Memory

```bash
# Reduce parallel jobs
./build_wheels.sh --max-jobs=2
```

#### Missing Dependencies

```bash
# Install all build dependencies
sudo apt-get install -y gcc-14 g++-14 cmake ninja-build ccache
```

### Publishing Failures

#### Wheel Already Exists

```bash
# PyPI doesn't allow overwriting. Increment version or delete old version
# Or use --skip-existing flag (automatic in scripts)
```

#### Invalid Token

```bash
# Verify token in .env file
cat .env

# Regenerate token at https://pypi.org/manage/account/token/
```

### Installation Issues

#### Wrong Package Installed

```bash
# Uninstall all vllm packages
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y

# Reinstall correct package
pip install vllm-cpu-avx512bf16
```

#### Import Errors

```bash
# Check PyTorch installation
python -c "import torch; print(torch.__version__)"

# Reinstall PyTorch
pip install torch==2.8.0+cpu --extra-index-url https://download.pytorch.org/whl/cpu
```

## Maintenance

### Regular Tasks

1. **Monitor upstream vLLM**: Check for new releases weekly
2. **Update dependencies**: Keep cpu.txt, cpu-build.txt in sync with upstream
3. **Test builds**: Run test builds monthly to catch dependency issues
4. **Update documentation**: Keep CPU compatibility guide current

### Updating Dependencies

```bash
# Sync with upstream vLLM requirements
cd /tmp
git clone https://github.com/vllm-project/vllm.git
cd vllm

# Compare and update
diff requirements/cpu.txt /path/to/vllm-cpu/resources/cpu.txt
diff requirements/cpu-build.txt /path/to/vllm-cpu/resources/cpu-build.txt
```

## Support

### Getting Help

- **vLLM Documentation**: https://docs.vllm.ai/
- **vLLM GitHub**: https://github.com/vllm-project/vllm
- **PyPI Help**: https://pypi.org/help/

### Reporting Issues

When reporting issues, include:

1. Package name and version
2. CPU model and features (output of `lscpu`)
3. Python version
4. Operating system
5. Error messages and logs

## License

Apache License 2.0 (same as vLLM)

## Acknowledgments

This project builds upon the excellent work of the vLLM team:
- **Upstream vLLM**: https://github.com/vllm-project/vllm
- **vLLM Team**: https://github.com/vllm-project/vllm/graphs/contributors
