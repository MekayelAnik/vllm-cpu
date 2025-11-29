# Building All Variants at Once

## Quick Start

```bash
# Build all 5 variants sequentially
./build_wheels.sh --variant=all

# Or without specifying variant (same result)
./build_wheels.sh
```

## Overview

The `--variant=all` option builds all 5 CPU-optimized wheel variants in a single command:

1. **vllm-cpu** (baseline, no AVX512)
2. **vllm-cpu-avx512** (AVX512)
3. **vllm-cpu-avx512vnni** (AVX512 + VNNI)
4. **vllm-cpu-avx512bf16** (AVX512 + VNNI + BF16)
5. **vllm-cpu-amxbf16** (AVX512 + VNNI + BF16 + AMX)

## Time Estimate

⏱️ **Total time: 2.5 - 5 hours**

- Per variant: ~30-60 minutes
- 5 variants × 30-60 min = 2.5-5 hours total

## Basic Usage

### Simple Build (All Defaults)

```bash
# Build all variants with default settings
./build_wheels.sh --variant=all
```

**Defaults:**
- Python version: 3.13
- Output directory: ./dist
- Max jobs: All CPU cores
- Cleanup: Enabled

### Custom Build Options

```bash
# Build all with custom settings
./build_wheels.sh \
  --variant=all \
  --vllm-version=v0.6.3 \
  --python-version=3.13 \
  --output-dir=./wheels \
  --max-jobs=8 \
  --no-cleanup
```

## Command Options

| Option | Description | Default |
|--------|-------------|---------|
| `--variant=all` | Build all 5 variants | N/A |
| `--vllm-version=VERSION` | vLLM version to build | Latest git tag |
| `--python-version=3.X` | Python version | 3.13 |
| `--output-dir=PATH` | Where to save wheels | ./dist |
| `--max-jobs=N` | Parallel build jobs | CPU count |
| `--no-cleanup` | Keep build files | Disabled |

## Build Process

### What Happens

```
[INFO] Building all 5 variants (this will take 2.5-5 hours)...
========================================
[INFO] Building variant: vllm-cpu
[INFO] Package: vllm-cpu
[INFO] AVX512 Disabled: true
... (building, ~30-60 min)
[SUCCESS] Built wheel for vllm-cpu
========================================

========================================
[INFO] Building variant: vllm-cpu-avx512
[INFO] Package: vllm-cpu-avx512
[INFO] AVX512 Disabled: false
... (building, ~30-60 min)
[SUCCESS] Built wheel for vllm-cpu-avx512
========================================

... (repeats for all 5 variants)

[SUCCESS] All variants built successfully!
[INFO] Built wheels:
-rw-r--r-- 1 user user 245M vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- 1 user user 248M vllm_cpu_avx512-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- 1 user user 249M vllm_cpu_avx512vnni-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- 1 user user 250M vllm_cpu_avx512bf16-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- 1 user user 252M vllm_cpu_amxbf16-0.6.3-cp313-cp313-linux_x86_64.whl
```

### Build Order

Variants are built in alphabetical order:
1. vllm-cpu
2. vllm-cpu-amxbf16
3. vllm-cpu-avx512
4. vllm-cpu-avx512bf16
5. vllm-cpu-avx512vnni

## Example Scenarios

### Scenario 1: Production Release

Build all variants for PyPI release:

```bash
#!/bin/bash
set -e

# Clean previous builds
rm -rf dist/

# Build all variants
./build_wheels.sh \
  --variant=all \
  --vllm-version=v0.6.3 \
  --max-jobs=16

# Validate all wheels
for wheel in dist/*.whl; do
    echo "Validating $wheel..."
    twine check "$wheel"
done

# Publish to Test PyPI first
./publish_to_pypi.sh --test --skip-build

echo "✓ All variants built and validated!"
```

### Scenario 2: Development Build

Fast build with limited resources:

```bash
# Build all with reduced parallelism
./build_wheels.sh \
  --variant=all \
  --max-jobs=4 \
  --no-cleanup
```

### Scenario 3: Specific Version

Build all variants for a specific vLLM version:

```bash
# Build v0.6.0 for all CPU types
./build_wheels.sh \
  --variant=all \
  --vllm-version=v0.6.0
```

### Scenario 4: Background Build

Run build in background and log output:

```bash
# Start build in background
nohup ./build_wheels.sh --variant=all > build.log 2>&1 &
BUILD_PID=$!

# Monitor progress
tail -f build.log

# Check if still running
ps -p $BUILD_PID
```

## Monitoring Progress

### Real-time Monitoring

```bash
# Terminal 1: Run build
./build_wheels.sh --variant=all

# Terminal 2: Watch progress
watch -n 5 'ls -lh dist/*.whl 2>/dev/null | tail -5'
```

### Enhanced Logging

Use the enhanced script for better logging:

```bash
# With timestamps and PIDs
./build_wheels_enhanced.sh --variant=all 2>&1 | tee build.log
```

Output shows:
```
2025-11-21 17:30:00 [12345] [INFO] Building all 5 variants...
2025-11-21 17:30:01 [12345] [INFO] Building variant: vllm-cpu
...
```

## Resource Requirements

### System Requirements

- **CPU**: Multi-core recommended (16+ cores ideal)
- **RAM**: 32GB minimum, 64GB recommended
- **Disk**: 50GB free space minimum
- **Time**: 2.5-5 hours

### Resource Usage Per Variant

| Resource | Per Variant | All 5 Variants |
|----------|-------------|----------------|
| Build Time | 30-60 min | 2.5-5 hours |
| Disk Space (temp) | ~10GB | ~10GB (reused) |
| Disk Space (wheels) | ~250MB | ~1.2GB |
| RAM Usage | 8-16GB | 8-16GB |

## Output

### Expected Output Structure

```
dist/
├── vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
├── vllm_cpu_avx512-0.6.3-cp313-cp313-linux_x86_64.whl
├── vllm_cpu_avx512vnni-0.6.3-cp313-cp313-linux_x86_64.whl
├── vllm_cpu_avx512bf16-0.6.3-cp313-cp313-linux_x86_64.whl
└── vllm_cpu_amxbf16-0.6.3-cp313-cp313-linux_x86_64.whl
```

### Wheel Sizes

Approximate sizes (version 0.6.3):
- vllm-cpu: ~245MB
- vllm-cpu-avx512: ~248MB
- vllm-cpu-avx512vnni: ~249MB
- vllm-cpu-avx512bf16: ~250MB
- vllm-cpu-amxbf16: ~252MB

**Total**: ~1.2GB

## Troubleshooting

### Build Fails on One Variant

If one variant fails, the script stops. To continue from where it left off:

```bash
# Check which variants are already built
ls -lh dist/

# Build missing variants individually
./build_wheels.sh --variant=vllm-cpu-avx512bf16
./build_wheels.sh --variant=vllm-cpu-amxbf16
```

### Out of Memory

```bash
# Reduce parallel jobs
./build_wheels.sh --variant=all --max-jobs=2

# Or build on a machine with more RAM
```

### Out of Disk Space

```bash
# Clean up before building
rm -rf dist/ /tmp/vllm-build/

# Or specify different output directory
./build_wheels.sh --variant=all --output-dir=/mnt/large-disk/wheels
```

### Build Takes Too Long

```bash
# Increase parallelism (if you have the RAM)
./build_wheels.sh --variant=all --max-jobs=32

# Or build only needed variants
./build_wheels.sh --variant=vllm-cpu-avx512bf16
```

## Comparison: All vs Individual

### Build All Variants

```bash
# One command
./build_wheels.sh --variant=all

# Pros:
# - Simple single command
# - Consistent build environment
# - Sequential, predictable
# - Automatic cleanup between variants

# Cons:
# - Takes 2.5-5 hours total
# - If one fails, need to restart
# - Can't parallelize across variants
```

### Build Individual Variants

```bash
# Multiple commands
./build_wheels.sh --variant=vllm-cpu
./build_wheels.sh --variant=vllm-cpu-avx512
./build_wheels.sh --variant=vllm-cpu-avx512vnni
./build_wheels.sh --variant=vllm-cpu-avx512bf16
./build_wheels.sh --variant=vllm-cpu-amxbf16

# Pros:
# - Can parallelize on multiple machines
# - Can skip variants you don't need
# - Easier to debug individual failures
# - Can customize per variant

# Cons:
# - More commands to manage
# - Need to track which are done
# - More manual work
```

## Automation

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Build all vLLM CPU variants
  run: |
    ./build_wheels.sh \
      --variant=all \
      --vllm-version=${{ github.event.inputs.vllm_version }} \
      --max-jobs=8
  timeout-minutes: 360  # 6 hours
```

### Cron Job

```bash
# Build nightly
0 2 * * * cd /path/to/vllm-cpu && ./build_wheels.sh --variant=all > /var/log/vllm-build.log 2>&1
```

## Post-Build Actions

### Validate All Wheels

```bash
# Install twine
pip install twine

# Validate all wheels
for wheel in dist/*.whl; do
    echo "Checking $wheel..."
    twine check "$wheel" || exit 1
done

echo "✓ All wheels validated successfully"
```

### Test All Wheels

```bash
# Test each wheel
for wheel in dist/*.whl; do
    echo "Testing $wheel..."

    # Create temp venv
    python -m venv test_venv
    source test_venv/bin/activate

    # Install wheel
    pip install "$wheel"

    # Test import
    python -c "import vllm; print(f'✓ {wheel}: vLLM {vllm.__version__}')"

    # Cleanup
    deactivate
    rm -rf test_venv
done
```

### Publish All Wheels

```bash
# Test PyPI first
./publish_to_pypi.sh --test --skip-build

# Then production PyPI
./publish_to_pypi.sh --skip-build
```

## Performance Tips

### 1. Use Fast Disk

```bash
# Build on SSD/NVMe for faster I/O
./build_wheels.sh --variant=all --output-dir=/mnt/nvme/wheels
```

### 2. Maximize Parallelism

```bash
# Use all available cores (if you have the RAM)
./build_wheels.sh --variant=all --max-jobs=$(nproc)
```

### 3. Use ccache

The build script automatically uses ccache if available:

```bash
# Install ccache for faster rebuilds
sudo apt-get install ccache

# Build will automatically use it
./build_wheels.sh --variant=all
```

### 4. Keep Workspace

```bash
# First build
./build_wheels.sh --variant=all --no-cleanup

# Subsequent builds will be faster (reuses cloned repo)
./build_wheels.sh --variant=all
```

## Summary

### Quick Reference

```bash
# Build all variants (simple)
./build_wheels.sh --variant=all

# Build all variants (with options)
./build_wheels.sh --variant=all --max-jobs=8 --vllm-version=v0.6.3

# Monitor progress
tail -f build.log

# Validate results
ls -lh dist/*.whl
twine check dist/*.whl

# Total output
# 5 wheels, ~1.2GB total, 2.5-5 hours
```

### When to Use --variant=all

✅ **Use `--variant=all` when:**
- Preparing a PyPI release
- Building complete distribution
- Testing all CPU optimizations
- Creating offline package repository
- You have 2.5-5 hours available

❌ **Don't use `--variant=all` when:**
- You only need one variant
- Limited time available
- Testing specific optimization
- Low on disk space or RAM
- Building on slow hardware

---

**Related Documentation:**
- See `CLAUDE.md` for full build system documentation
- See `build_config.json` for variant configuration
- See `DEPLOYMENT_CHECKLIST.md` for production deployment

**Support:**
- For build issues: Check build logs in /tmp/vllm-build/
- For disk space: Use `df -h` and `du -sh dist/`
- For memory: Use `free -h` and reduce `--max-jobs`
