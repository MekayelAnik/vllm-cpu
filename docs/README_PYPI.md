# vLLM CPU - PyPI Distribution

CPU-optimized builds of [vLLM](https://github.com/vllm-project/vllm) for PyPI distribution. Provides 5 pre-built packages optimized for different CPU instruction sets.

## 🎯 Available Packages

| Package | AVX512 | VNNI | BF16 | AMX | Best For |
|---------|--------|------|------|-----|----------|
| [`vllm-cpu`](https://pypi.org/project/vllm-cpu/) | ❌ | ❌ | ❌ | ❌ | Older CPUs, ARM64 |
| [`vllm-cpu-avx512`](https://pypi.org/project/vllm-cpu-avx512/) | ✅ | ❌ | ❌ | ❌ | Intel Skylake-X+ |
| [`vllm-cpu-avx512vnni`](https://pypi.org/project/vllm-cpu-avx512vnni/) | ✅ | ✅ | ❌ | ❌ | Intel Cascade Lake+ |
| [`vllm-cpu-avx512bf16`](https://pypi.org/project/vllm-cpu-avx512bf16/) | ✅ | ✅ | ✅ | ❌ | Intel Cooper Lake+ |
| [`vllm-cpu-amxbf16`](https://pypi.org/project/vllm-cpu-amxbf16/) | ✅ | ✅ | ✅ | ✅ | Intel Sapphire Rapids+ |

## 🚀 Quick Start

### Automatic Detection (Recommended)

```bash
# Install CPU detection tool
pip install vllm-cpu-detect

# Detect your CPU and get recommendation
vllm-cpu-detect

# Install recommended package
pip install vllm-cpu-amxbf16  # Example recommendation
```

### Manual Installation

```bash
# Check your CPU features
lscpu | grep -i "avx512\|vnni\|bf16\|amx"

# Install appropriate package
pip install vllm-cpu-avx512bf16
```

## 📚 Documentation

- **Quick Start**: [QUICK_START.md](QUICK_START.md)
- **Full Publishing Guide**: [PYPI_PUBLISHING_GUIDE.md](PYPI_PUBLISHING_GUIDE.md)
- **vLLM Documentation**: https://docs.vllm.ai/

## 🏗️ For Package Maintainers

### Building Wheels

```bash
# Install dependencies
sudo apt-get install -y gcc-14 g++-14 cmake ninja-build ccache
curl -LsSf https://astral.sh/uv/install.sh | sh

# Build all variants (2-5 hours)
./build_wheels.sh

# Build specific variant (30-60 minutes)
./build_wheels.sh --variant=vllm-cpu-avx512bf16
```

### Publishing to PyPI

```bash
# Setup credentials in .env file
cat > .env << 'EOF'
PYPI_API_TOKEN=pypi-YOUR_TOKEN_HERE
TEST_PYPI_API_TOKEN=pypi-YOUR_TEST_TOKEN_HERE
EOF

# Test publish
./publish_to_pypi.sh --test

# Production publish
./publish_to_pypi.sh
```

### Automated CI/CD

Push a version tag to automatically build and publish:

```bash
git tag v0.11.2
git push origin v0.11.2
```

See [.github/workflows/build-and-publish.yml](.github/workflows/build-and-publish.yml) for details.

## 🔧 Project Structure

```
vllm-cpu/
├── build_config.json              # Build configuration
├── build_wheels.sh                # Build script
├── publish_to_pypi.sh             # Publishing script
├── generate_package_metadata.py   # Metadata generator
├── cpu_detect/                    # CPU detection tool
│   ├── vllm_cpu_detect.py
│   └── setup.py
├── .github/workflows/
│   └── build-and-publish.yml      # CI/CD workflow
└── resources/
    ├── pypi-builder.sh
    ├── common.txt
    ├── cpu.txt
    └── cpu-build.txt
```

## 💡 Key Features

- **5 optimized builds** for different CPU architectures
- **Automatic CPU detection** tool
- **CI/CD automation** via GitHub Actions
- **Easy publishing** with one-command deployment
- **Debian Trixie** optimized builds
- **Python 3.9-3.13** support
- **ARM64 and x86_64** platform support

## 🎓 CPU Compatibility Guide

### Intel Generations

| CPU Generation | Recommended Package |
|----------------|---------------------|
| Sapphire Rapids (4th Gen Xeon), Emerald Rapids (5th Gen Xeon) | `vllm-cpu-amxbf16` |
| Cooper Lake, Ice Lake, Tiger Lake, Rocket Lake | `vllm-cpu-avx512bf16` |
| Cascade Lake, Ice Lake (without BF16) | `vllm-cpu-avx512vnni` |
| Skylake-X/W, Cascade Lake (without VNNI) | `vllm-cpu-avx512` |
| Older Intel CPUs | `vllm-cpu` |

### ARM Processors

| Processor | Recommended Package |
|-----------|---------------------|
| All ARM64/AArch64 | `vllm-cpu` |

### AMD Processors

| Processor | Recommended Package |
|-----------|---------------------|
| Zen 4+ (with AVX512) | `vllm-cpu-avx512` |
| Older AMD CPUs | `vllm-cpu` |

## 📦 Package Versions

All packages follow the upstream vLLM version numbering:

- **Upstream vLLM**: `0.11.2`
- **Your packages**: `0.11.2` (same version, different builds)

## 🔗 Links

- **Upstream vLLM**: https://github.com/vllm-project/vllm
- **vLLM Documentation**: https://docs.vllm.ai/
- **PyPI Project**: https://pypi.org/project/vllm-cpu/
- **Issues**: https://github.com/vllm-project/vllm/issues

## 📄 License

Apache License 2.0 (same as vLLM)

## 🙏 Acknowledgments

Built on top of the excellent [vLLM project](https://github.com/vllm-project/vllm) by the vLLM team.

## 💬 Support

For questions and issues:

1. **vLLM usage**: See [vLLM documentation](https://docs.vllm.ai/)
2. **Build/packaging issues**: Open an issue in this repository
3. **vLLM bugs**: Report to [upstream vLLM](https://github.com/vllm-project/vllm/issues)

---

**Note**: This is an independent packaging project. For vLLM functionality issues, please refer to the [upstream vLLM repository](https://github.com/vllm-project/vllm).
