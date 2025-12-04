# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds and publishes **5 CPU-optimized vLLM wheel packages** to PyPI, each compiled with different instruction set extensions for optimal performance on different Intel/AMD CPUs. The project clones the upstream vLLM repository, builds custom wheels with CPU-specific compiler flags, and publishes them as separate PyPI packages.

### The 5 Package Variants

| Package | AVX512 | VNNI | BF16 | AMX | Target CPUs | Architectures |
|---------|--------|------|------|-----|-------------|---------------|
| `vllm-cpu` | ❌ | ❌ | ❌ | ❌ | All CPUs (base build) | x86_64, ARM64/AArch64 |
| `vllm-cpu-avx512` | ✅ | ❌ | ❌ | ❌ | Intel Skylake-X+ | x86_64 only |
| `vllm-cpu-avx512vnni` | ✅ | ✅ | ❌ | ❌ | Intel Cascade Lake+ | x86_64 only |
| `vllm-cpu-avx512bf16` | ✅ | ✅ | ✅ | ❌ | Intel Cooper Lake+ | x86_64 only |
| `vllm-cpu-amxbf16` | ✅ | ✅ | ✅ | ✅ | Intel Sapphire Rapids (4th gen Xeon)+ | x86_64 only |

**Platform Support:**
- **vllm-cpu**: Universal build supporting both x86_64 (Intel/AMD) and ARM64/AArch64 (AWS Graviton, Apple Silicon, etc.)
- **Optimized variants**: x86_64 only (Intel/AMD-specific instruction sets)

### ARM64 Build Options

Building ARM64 wheels requires native ARM64 infrastructure. **QEMU emulation does not work** due to GCC internal compiler errors when compiling oneDNN's JIT code.

**Recommended approaches:**

1. **GitHub Actions ARM64 runners** (easiest):
   ```yaml
   jobs:
     build-arm64:
       runs-on: ubuntu-24.04-arm  # Native ARM64 runner
       steps:
         - uses: actions/checkout@v4
         - run: ./build_wheels.sh --variant=vllm-cpu
   ```

2. **Native ARM64 systems**:
   - AWS Graviton instances (t4g, c7g, m7g)
   - Oracle Cloud ARM instances (free tier available)
   - Raspberry Pi 4/5 (slower but works)
   - Apple Silicon via Docker

3. **Self-hosted ARM64 runner** for GitHub Actions

**Why QEMU doesn't work:**
- vLLM builds oneDNN which contains JIT compilation code
- GCC crashes with "internal compiler error: Segmentation fault" under QEMU
- This is a fundamental QEMU limitation, not fixable with patches

## Common Commands

### Building Wheels with Docker (Recommended)

**Docker-based builds provide isolated, reproducible environments and support cross-platform compilation.**

Uses `docker-buildx.sh` with `Dockerfile.buildx` for multi-architecture builds:

```bash
# Build vllm-cpu for both amd64 and arm64 (auto-detected from build_config.json)
./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2

# Build x86-only variant (avx512 variants only support x86_64)
./docker-buildx.sh --variant=vllm-cpu-avx512bf16 --vllm-version=0.11.2

# Build with specific platform override
./docker-buildx.sh --variant=vllm-cpu --platform=linux/arm64 --vllm-version=0.11.2

# Build with custom output directory
./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2 --output-dir=./my-wheels

# Build multiple Python versions (loop)
for pyver in 3.10 3.11 3.12 3.13; do
    ./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2 --python-version=$pyver
done

# Build without Docker cache (fresh build)
./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2 --no-cache
```

**Testing built wheels in Docker:**
```bash
# Test a wheel in a clean container
docker run --rm -v $(pwd)/dist:/wheels python:3.12-slim \
  sh -c 'pip install /wheels/vllm_cpu-*.whl && python -c "import vllm; print(vllm.__version__)"'

# Test on ARM64 (via QEMU emulation)
docker run --rm --platform linux/arm64 -v $(pwd)/dist:/wheels python:3.12-slim \
  sh -c 'pip install /wheels/vllm_cpu-*aarch64.whl && python -c "import vllm; print(vllm.__version__)"'
```

### Building Wheels (Native)

**Note**: Built wheels include all runtime dependencies (PyTorch, transformers, etc.) automatically. Users only need to `pip install` the wheel.

```bash
# Build all 5 variants (2.5-5 hours total)
./build_wheels.sh
# Or explicitly:
./build_wheels.sh --variant=all

# Build specific variant (30-60 minutes)
./build_wheels.sh --variant=vllm-cpu-avx512bf16

# Build with custom vLLM version
./build_wheels.sh --variant=vllm-cpu-amxbf16 --vllm-versions=0.11.2

# Build multiple vLLM versions (comma-separated)
./build_wheels.sh --vllm-versions=0.10.0,0.10.1,0.11.0,0.11.1

# Build for multiple Python versions (range)
./build_wheels.sh --python-versions=3.10-3.13

# Build version matrix: multiple vLLM × multiple Python versions
# Example: 7 vLLM versions × 4 Python versions = 28 wheels per variant
./build_wheels.sh --vllm-versions=0.10.0,0.10.1,0.10.1.1,0.10.2,0.11.0,0.11.1,0.11.2 --python-versions=3.10-3.13

# Build all variants for multiple versions (140 total wheels)
# 7 vLLM versions × 4 Python versions × 5 variants = 140 wheels
./build_wheels.sh --variant=all --vllm-versions=0.10.0,0.10.1,0.10.1.1,0.10.2,0.11.0,0.11.1,0.11.2 --python-versions=3.10-3.13

# NOTE: Singular forms (--vllm-version, --python-version) are deprecated but still work for backward compatibility
# Recommended: Always use --vllm-versions and --python-versions (plural forms)

# Build with limited parallel jobs (if memory constrained)
./build_wheels.sh --max-jobs=2

# Build without cleanup (for debugging)
./build_wheels.sh --variant=vllm-cpu --no-cleanup

# Output wheels to custom directory
./build_wheels.sh --output-dir=./my-wheels
```

**Output Directory Structure:**

When building multiple versions, wheels are organized as:
```
dist/
├── vllm-0.10.0/
│   ├── python-3.10/
│   │   ├── vllm_cpu-0.10.0+cpu-cp310-*.whl
│   │   ├── vllm_cpu_avx512-0.10.0+cpu-cp310-*.whl
│   │   └── ...
│   ├── python-3.11/
│   └── python-3.12/
├── vllm-0.11.0/
│   ├── python-3.10/
│   ├── python-3.11/
│   └── python-3.12/
└── *.whl (all wheels also copied here for convenience)
```

### Publishing Wheels (Build-Verify-Publish Pipeline)

The `test_and_publish.sh` script (v3.0.0) implements a streamlined Build-Verify-Publish workflow:

```bash
# Full workflow: Build → Verify → Publish to PyPI → GitHub Release
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.2

# Build and publish all 5 variants
./test_and_publish.sh --variant=all --vllm-versions=0.11.2

# Use existing wheels (skip build)
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.2 --skip-build

# Preview without making changes
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.2 --dry-run

# Skip GitHub release creation
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.2 --skip-github

# Update README in existing wheels (no rebuild, no upload)
./test_and_publish.sh --update-readme --variant=all --vllm-versions=0.11.2
```

**Workflow Phases:**
1. **Phase 0**: Pre-flight checks (PyPI status, local wheels)
2. **Phase 1**: Build and validate wheels
3. **Wheel Verification**: Automatic integrity checks (ZIP, structure, metadata, twine)
4. **Rebuild-on-Failure**: If verification fails, auto-rebuild (max 2 attempts)
5. **Phase 2**: Publish to production PyPI
6. **Phase 3**: Create GitHub release

**Note**: Test PyPI verification was removed in v3.0.0. Wheels are verified locally before publishing directly to production PyPI.

### Building CPU Detector Tool

```bash
cd cpu_detect
python -m build
twine upload dist/* --username __token__ --password $PYPI_API_TOKEN
```

### Testing Locally

```bash
# Install built wheel
pip install dist/vllm_cpu_avx512bf16-*.whl

# Test import
python -c "import vllm; print(vllm.__version__)"

# Test inference
python -c "from vllm import LLM; llm = LLM(model='facebook/opt-125m', device='cpu'); print(llm.generate('Hello'))"
```

## Architecture

### Build Flow

1. **build_wheels.sh** reads configuration from **build_config.json**
2. For each variant:
   - Creates isolated Python virtual environment at `/tmp/vllm-build/venv-{variant}`
   - Clones vLLM repository to `/tmp/vllm-build/vllm` (or reuses existing)
   - Modifies `pyproject.toml` to change package name and description
   - Adds Python version classifiers (3.10, 3.11, 3.12, 3.13) to pyproject.toml
   - Copies variant-specific README file (e.g., `noavx512_README.md` for vllm-cpu)
   - Sets CPU-specific environment variables (VLLM_CPU_DISABLE_AVX512, VLLM_CPU_AVX512VNNI, etc.)
   - Builds wheel: `python setup.py bdist_wheel`
   - Copies wheel to output directory (default: `./dist/`)
   - Restores original pyproject.toml and README.md

3. Cleanup: Removes build workspace (unless `--no-cleanup` specified)

### Build Configuration (build_config.json)

Defines all 5 package variants with:
- `package_name`: PyPI package name
- `description`: Package description
- `readme_file`: Variant-specific README file (e.g., `noavx512_README.md`, `avx512_README.md`)
- `flags`: CPU instruction set flags to enable/disable
  - `disable_avx512`: Disable AVX512 instructions
  - `enable_avx512vnni`: Enable VNNI (Vector Neural Network Instructions)
  - `enable_avx512bf16`: Enable BF16 (Brain Float 16)
  - `enable_amxbf16`: Enable AMX (Advanced Matrix Extensions)
- `platforms`: Supported platforms (x86_64, aarch64)
- `keywords`: PyPI search keywords

**README Mapping:**
- `vllm-cpu` → `noavx512_README.md`
- `vllm-cpu-avx512` → `avx512_README.md`
- `vllm-cpu-avx512vnni` → `avx512vnni_README.md`
- `vllm-cpu-avx512bf16` → `avx512bf16_README.md`
- `vllm-cpu-amxbf16` → `amxbf16_README.md`

**Python Version Support:**

| vLLM Version | Python Versions Supported |
|--------------|---------------------------|
| 0.10.0, 0.10.1 | 3.10, 3.11, 3.12 |
| 0.10.2+ | 3.10, 3.11, 3.12, 3.13 |
| 0.11.x+ | 3.10, 3.11, 3.12, 3.13 |

**Automatic Python Version Detection:**

The build scripts automatically fetch the `requires-python` constraint from vLLM's `pyproject.toml` on GitHub for each version. This means:
- No manual configuration needed when vLLM adds Python 3.14+ support
- The scripts automatically skip unsupported Python versions
- Falls back to hardcoded defaults if GitHub fetch fails (offline builds)

### Key Build Environment Variables

During wheel building, these environment variables control CPU optimizations:

- `VLLM_TARGET_DEVICE=cpu`: Target CPU device
- `VLLM_CPU_DISABLE_AVX512`: Set to 1 to disable AVX512
- `VLLM_CPU_AVX512VNNI`: Set to 1 to enable VNNI
- `VLLM_CPU_AVX512BF16`: Set to 1 to enable BF16
- `VLLM_CPU_AMXBF16`: Set to 1 to enable AMX
- `MAX_JOBS`: Number of parallel build jobs (default: CPU count)

### CI/CD Pipeline (.github/workflows/build-and-publish.yml)

Comprehensive GitHub Actions workflow with the following features:

**Triggers:**
- **Manual dispatch**: Build any vLLM version with custom variant selection
- **Version tags**: Automatically build and publish on `v*.*.*` tags
- **Pull requests**: Build and test (without publishing) on PRs to main/develop

**Jobs:**
1. **prepare-matrix**: Determines which variants to build and vLLM version
2. **build-wheels**: Builds all 5 variants in parallel with caching
3. **test-wheels**: Validates each wheel can be installed and imported
4. **github-release**: Creates GitHub releases with wheel attachments
5. **publish-pypi**: Publishes to PyPI/Test PyPI based on triggers
6. **build-summary**: Reports overall build status

**Features:**
- ✅ ccache and build artifact caching for faster rebuilds
- ✅ Selective variant building via workflow inputs
- ✅ Automatic wheel validation with `twine check`
- ✅ Import tests for each built wheel
- ✅ **Automatic GitHub releases with all 5 wheels attached**
- ✅ **Custom release notes with package table and installation instructions**
- ✅ 30-day artifact retention
- ✅ Smart PyPI publishing (Test PyPI for alpha/beta, PyPI for stable)
- ✅ Separate jobs for GitHub releases and PyPI publishing

**Required GitHub Secrets:**
- `PYPI_API_TOKEN` - Production PyPI token
- `TEST_PYPI_API_TOKEN` - Test PyPI token (optional, for CI workflows that still use Test PyPI)

**Manual Workflow Usage:**
```bash
# Via GitHub UI: Actions → Build and Publish → Run workflow
# Or via GitHub CLI:
gh workflow run build-and-publish.yml \
  -f vllm_version=v0.6.2 \
  -f publish_to_pypi=false \
  -f publish_to_test_pypi=true \
  -f variants="vllm-cpu-avx512bf16,vllm-cpu-amxbf16"
```

### CPU Detector Tool (cpu_detect/)

Python package `vllm-cpu-detect` that:
- Detects CPU instruction set features using `cpuinfo`
- Recommends the optimal vLLM CPU package variant
- Provides installation command

Users can run: `vllm-cpu-detect` to get recommendations.

## Dependency Management

All dependencies are managed through **pyproject.toml** in the upstream vLLM repository. The build script:

1. Clones the upstream vLLM repository
2. Modifies `pyproject.toml` to configure index URLs:
   - **Primary index**: `https://download.pytorch.org/whl/cpu` (for PyTorch, torchvision, torchaudio)
   - **Secondary index**: `https://pypi.org/simple` (for intel-openmp and other packages)
3. Installs all dependencies using: `uv pip install -e .`

This ensures PyTorch is always installed from the CPU-only index (no CUDA bloat) while other packages come from PyPI.

## Version Management

All 5 packages use the **same version number** as upstream vLLM:
- Upstream vLLM release: `0.11.2`
- All published packages: `0.11.2`

### Release Workflow

1. Monitor upstream releases: https://github.com/vllm-project/vllm/releases
2. Build, verify, and publish: `./test_and_publish.sh --variant=all --vllm-versions=0.11.2`
   - Builds wheels for all 5 variants
   - Verifies wheel integrity (auto-rebuilds on failure)
   - Publishes to production PyPI
   - Creates GitHub releases
3. Tag release: `git tag v0.11.2 && git push origin v0.11.2`

**Alternative (step-by-step):**
1. Build wheels: `./build_wheels.sh --variant=all --vllm-versions=0.11.2`
2. Test locally: `pip install dist/vllm_cpu_avx512bf16-*.whl`
3. Publish: `./test_and_publish.sh --variant=all --vllm-versions=0.11.2 --skip-build`

## Setup and Dependencies

### Initial Setup

```bash
# Install Python dev dependencies
pip install -e ".[dev]"

# Or install specific groups
pip install twine build wheel
```

### System Requirements
- Debian Trixie (or compatible Linux)
- gcc-14, g++-14
- cmake, ninja-build
- ccache (for faster rebuilds)
- libtcmalloc-minimal4 (performance optimization)
- libnuma-dev, numactl
- jq (for parsing build_config.json)
- git

### Python Tools
- uv (package manager): `curl -LsSf https://astral.sh/uv/install.sh | sh`
- twine (for PyPI publishing)
- build, wheel (for building wheels)

All Python dependencies are defined in `pyproject.toml`.

## Troubleshooting

### Build runs out of memory
```bash
./build_wheels.sh --max-jobs=2
```

### Build takes too long
Build variants sequentially instead of all at once:
```bash
for variant in vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16; do
    ./build_wheels.sh --variant=$variant
done
```

### Wrong package installed
```bash
# Uninstall all vllm packages
pip uninstall vllm vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16 -y

# Use detector to find right package
pip install vllm-cpu-detect
vllm-cpu-detect
```

### PyPI upload fails with "file already exists"
PyPI doesn't allow overwriting versions. Either:
- Increment the version number
- Use `--skip-existing` flag (automatically used in scripts)

## Docker Build System

The repository includes two Docker-based build systems:

### Docker Buildx (Recommended for Multi-Arch)

**`docker-buildx.sh`** leverages Docker buildx's native multi-architecture support to build wheels for multiple platforms (amd64/arm64) in a single command. The build process runs entirely inside Docker buildx, with wheels exported directly to the local filesystem without creating intermediate images.

```bash
# Build vllm-cpu for both amd64 and arm64 (auto-detected from build_config.json)
./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2

# Build x86-only variant (avx512 variants only support x86_64)
./docker-buildx.sh --variant=vllm-cpu-avx512bf16 --vllm-version=0.11.2

# Build with specific platform override
./docker-buildx.sh --variant=vllm-cpu --platform=linux/arm64 --vllm-version=0.11.2

# Build with custom output directory
./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2 --output-dir=./my-wheels

# Build multiple Python versions (loop)
for pyver in 3.10 3.11 3.12 3.13; do
    ./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2 --python-version=$pyver
done

# Build without Docker cache (fresh build)
./docker-buildx.sh --variant=vllm-cpu --vllm-version=0.11.2 --no-cache
```

**Output Structure (with platform-split):**
```
dist/
├── linux_amd64/
│   └── vllm_cpu-0.11.2-cp312-cp312-linux_x86_64.whl
└── linux_arm64/
    └── vllm_cpu-0.11.2-cp312-cp312-linux_aarch64.whl
```

**How it works:**
1. Creates a dedicated buildx builder (`vllm-wheel-builder`) with docker-container driver
2. Automatically registers QEMU handlers for cross-platform builds
3. Uses multi-stage `Dockerfile.buildx`:
   - **Stage 1 (builder)**: Clones vLLM, installs deps, builds wheel
   - **Stage 2 (export)**: `FROM scratch` with only wheel files
4. Exports wheels using `--output type=local,dest=./dist`
5. No intermediate Docker images are created or stored

**Key files:**
- **Dockerfile.buildx**: Multi-stage Dockerfile optimized for buildx artifact export
- **docker-buildx.sh**: Wrapper script that manages builder setup, QEMU, and build execution

**Advantages of Docker buildx:**
- ✅ True parallel multi-arch builds (both platforms build simultaneously)
- ✅ No intermediate Docker images created
- ✅ Leverages buildx's native caching
- ✅ Single command for multi-platform builds
- ✅ Isolated, reproducible build environments
- ✅ Cross-platform compilation (build ARM64 on x86_64, and vice versa)
- ✅ Better suited for CI/CD pipelines

## Docker Runtime Images

Pre-built Docker images are published to both Docker Hub and GitHub Container Registry (GHCR) for easy deployment without building from source.

### Image Repositories

- **Docker Hub**: `mekayelanik/vllm-cpu`
- **GitHub Container Registry**: `ghcr.io/mekayelanik/vllm-cpu`

### Image Tags

Each variant has two types of tags:
- `<variant>-<version>`: Specific version (e.g., `noavx512-0.11.2`)
- `<variant>-latest`: Latest version for that variant (e.g., `noavx512-latest`)

| Variant | Version Tag | Latest Tag | Platforms |
|---------|-------------|------------|-----------|
| noavx512 | `noavx512-0.11.2` | `noavx512-latest` | linux/amd64, linux/arm64 |
| avx512 | `avx512-0.11.2` | `avx512-latest` | linux/amd64 |
| avx512vnni | `avx512vnni-0.11.2` | `avx512vnni-latest` | linux/amd64 |
| avx512bf16 | `avx512bf16-0.11.2` | `avx512bf16-latest` | linux/amd64 |
| amxbf16 | `amxbf16-0.11.2` | `amxbf16-latest` | linux/amd64 |

### Pulling Images

```bash
# Docker Hub
docker pull mekayelanik/vllm-cpu:noavx512-latest
docker pull mekayelanik/vllm-cpu:avx512bf16-0.11.2

# GitHub Container Registry
docker pull ghcr.io/mekayelanik/vllm-cpu:noavx512-latest
```

### Running vLLM in Docker

```bash
# Basic usage - run OpenAI-compatible API server
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m

# With specific variant for better performance
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  mekayelanik/vllm-cpu:avx512bf16-latest \
  --model facebook/opt-125m \
  --max-model-len 2048

# Run with custom configuration
docker run -p 8000:8000 \
  -v /path/to/models:/models \
  -e OMP_NUM_THREADS=8 \
  mekayelanik/vllm-cpu:amxbf16-latest \
  --model /models/my-model \
  --host 0.0.0.0 \
  --port 8000

# Interactive mode for debugging
docker run -it --rm \
  mekayelanik/vllm-cpu:noavx512-latest \
  python -c "import vllm; print(vllm.__version__)"
```

### Docker Compose Example

```yaml
version: '3.8'
services:
  vllm:
    image: mekayelanik/vllm-cpu:noavx512-latest
    ports:
      - "8000:8000"
    volumes:
      - huggingface-cache:/root/.cache/huggingface
    environment:
      - OMP_NUM_THREADS=8
      - MKL_NUM_THREADS=8
    command: ["--model", "facebook/opt-125m", "--host", "0.0.0.0"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  huggingface-cache:
```

### Building Docker Images Locally

```bash
# Build a specific variant
docker build \
  --build-arg VLLM_VERSION=0.11.2 \
  --build-arg VARIANT=noavx512 \
  --build-arg PYTHON_VERSION=3.12 \
  -t vllm-cpu:noavx512-0.11.2 \
  -f docker/Dockerfile \
  docker/

# Build using GitHub release instead of PyPI
docker build \
  --build-arg VLLM_VERSION=0.11.2 \
  --build-arg VARIANT=avx512bf16 \
  --build-arg USE_GITHUB_RELEASE=true \
  -t vllm-cpu:avx512bf16-0.11.2 \
  -f docker/Dockerfile \
  docker/
```

### CI/CD: GitHub Actions Workflow

The `docker-publish.yml` workflow builds and publishes Docker images:

```bash
# Trigger manually via GitHub Actions UI or CLI
gh workflow run docker-publish.yml \
  -f vllm_version=0.11.2 \
  -f variants=all \
  -f platforms=all \
  -f push=true
```

**Workflow features:**
- Builds all 5 variants in parallel
- Publishes to both Docker Hub and GHCR
- Multi-platform support (amd64 + arm64 for noavx512)
- Automatic Python version detection from vLLM's requirements
- Falls back to GitHub release wheels if PyPI unavailable
- Triggered on release creation or manual dispatch

**Required GitHub Secrets:**
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token
- `GITHUB_TOKEN` - Automatically provided for GHCR

### Image Architecture

The Docker images are built from the pre-compiled PyPI wheels (or GitHub release wheels as fallback):

```
docker/
└── Dockerfile          # Runtime image from PyPI/GitHub wheels
```

**Key features:**
- Minimal runtime image based on `python:3.x-slim-bookworm`
- Non-root user (`vllm`) for security
- Health check endpoint at `/health`
- Automatic CPU variant selection via environment variable
- Performance tuning via `OMP_NUM_THREADS`, `MKL_NUM_THREADS`

## License

GNU General Public License v3.0

The published wheel packages follow vLLM's original Apache License 2.0.
