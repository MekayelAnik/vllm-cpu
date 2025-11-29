# Multi-Wheel Support in test_and_publish.sh

> **Note**: This documentation describes v2.0.0 features. As of v3.0.0, the workflow has been simplified:
> - Test PyPI verification has been removed
> - `--skip-test-pypi` argument no longer exists
> - Workflow is now: Build → Verify → Publish to Production PyPI
> - See `TEST_AND_PUBLISH.md` for current v3.0.0 documentation

## Overview

Version 2.0.0 of `test_and_publish.sh` introduced multi-wheel support. Version 3.0.0 simplified the workflow by removing Test PyPI verification. This document describes the multi-wheel capabilities which remain in v3.0.0.

## What's New in v2.0.0

### Features Added
1. ✅ **Multi-wheel detection**: Automatically finds and processes all `.whl` files in `dist/`
2. ✅ **Batch validation**: Validates all wheels with `twine check` in one pass
3. ✅ **Parallel testing**: Tests all packages from TestPyPI in separate environments
4. ✅ **Bulk publishing**: Publishes all wheels to PyPI via `publish_to_pypi.sh`
5. ✅ **Smart mode detection**: Automatically enables multi-wheel mode when appropriate
6. ✅ **Backward compatible**: Single-wheel workflow still works exactly as before

### New Arrays
- `WHEEL_PATHS[]`: Array of all wheel file paths
- `PACKAGE_NAMES[]`: Array of all package names
- `DETECTED_VERSIONS[]`: Array of all detected versions

### New Functions
- `find_all_wheels()`: Finds all wheels in dist/ directory
- `validate_all_wheels()`: Validates all wheels with twine
- `test_all_installations()`: Tests installation of all packages from TestPyPI

---

## Usage

### Multi-Wheel Workflow

#### Option 1: Build All + Test + Publish
```bash
# Build all 5 variants, then test and publish all
./test_and_publish.sh --variant=all
```

#### Option 2: Use Existing Wheels
```bash
# If you already have wheels in dist/, skip building
./test_and_publish.sh --skip-build
```

#### Option 3: TestPyPI Only
```bash
# Test all wheels on TestPyPI only (no production publish)
./test_and_publish.sh --variant=all --dry-run
```

#### Option 4: Skip GitHub Releases
```bash
# Test and publish all, but skip GitHub releases
./test_and_publish.sh --variant=all --skip-github
```

---

## Complete Workflow Examples

### Example 1: Full Pipeline (All Variants)

```bash
# Step 1: Build all 5 variants (takes 2.5-5 hours)
./build_wheels.sh --variant=all

# Step 2: Test and publish all variants
./test_and_publish.sh --skip-build

# What happens:
# 1. Finds all 5 wheels in dist/
# 2. Validates all 5 with twine
# 3. Publishes all 5 to TestPyPI
# 4. Tests installation of all 5 from TestPyPI
# 5. Publishes all 5 to production PyPI (after confirmation)
# 6. Skips GitHub releases (use individual releases later)
```

**Expected Output:**
```
2025-11-21 19:00:00 [INFO] Starting test-then-publish workflow (v2.0.0)
2025-11-21 19:00:00 [INFO] Multi-wheel mode enabled
2025-11-21 19:00:00 [INFO] === Phase 1: Build and Validate ===
2025-11-21 19:00:00 [INFO] Locating all wheels in dist/ directory...
2025-11-21 19:00:00 [INFO] Found 5 wheel(s)
2025-11-21 19:00:00 [INFO]   - vllm_cpu-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:00 [INFO]     Package: vllm-cpu, Version: 0.6.3
2025-11-21 19:00:00 [INFO]   - vllm_cpu_avx512-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:00 [INFO]     Package: vllm-cpu-avx512, Version: 0.6.3
2025-11-21 19:00:00 [INFO]   - vllm_cpu_avx512vnni-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:00 [INFO]     Package: vllm-cpu-avx512vnni, Version: 0.6.3
2025-11-21 19:00:00 [INFO]   - vllm_cpu_avx512bf16-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:00 [INFO]     Package: vllm-cpu-avx512bf16, Version: 0.6.3
2025-11-21 19:00:00 [INFO]   - vllm_cpu_amxbf16-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:00 [INFO]     Package: vllm-cpu-amxbf16, Version: 0.6.3
2025-11-21 19:00:00 [INFO] Validating 5 wheel(s) with twine...
2025-11-21 19:00:01 [SUCCESS] ✓ vllm_cpu-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:02 [SUCCESS] ✓ vllm_cpu_avx512-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:03 [SUCCESS] ✓ vllm_cpu_avx512vnni-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:04 [SUCCESS] ✓ vllm_cpu_avx512bf16-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:05 [SUCCESS] ✓ vllm_cpu_amxbf16-0.6.3-py3-none-linux_x86_64.whl
2025-11-21 19:00:05 [SUCCESS] All wheels validated successfully
...
2025-11-21 19:00:30 [SUCCESS] Complete workflow finished successfully!
2025-11-21 19:00:30 [INFO] Processed 5 package(s):
2025-11-21 19:00:30 [INFO]   ✓ vllm-cpu v0.6.3
2025-11-21 19:00:30 [INFO]   ✓ vllm-cpu-avx512 v0.6.3
2025-11-21 19:00:30 [INFO]   ✓ vllm-cpu-avx512vnni v0.6.3
2025-11-21 19:00:30 [INFO]   ✓ vllm-cpu-avx512bf16 v0.6.3
2025-11-21 19:00:30 [INFO]   ✓ vllm-cpu-amxbf16 v0.6.3
```

---

### Example 2: Build + Test + Publish in One Command

```bash
# Build all variants and publish in one command
./test_and_publish.sh --variant=all
```

**Timeline:**
- **Hours 0-5**: Building all 5 variants (longest step)
- **Hour 5**: Validating all wheels with twine
- **Hour 5**: Publishing to TestPyPI
- **Hour 5-6**: Testing all 5 installations
- **Hour 6**: Publishing to production PyPI

---

### Example 3: Dry-Run Before Real Publish

```bash
# First, test what would happen (dry-run)
./build_wheels.sh --variant=all
./test_and_publish.sh --skip-build --dry-run

# If everything looks good, do the real publish
./test_and_publish.sh --skip-build
```

---

### Example 4: Individual GitHub Releases

Since GitHub releases are skipped in multi-wheel mode, create them individually:

```bash
# After publishing all wheels to PyPI
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-test-pypi
./test_and_publish.sh --variant=vllm-cpu-avx512 --skip-build --skip-test-pypi
./test_and_publish.sh --variant=vllm-cpu-avx512vnni --skip-build --skip-test-pypi
./test_and_publish.sh --variant=vllm-cpu-avx512bf16 --skip-build --skip-test-pypi
./test_and_publish.sh --variant=vllm-cpu-amxbf16 --skip-build --skip-test-pypi
```

---

## Single-Wheel Workflow (Unchanged)

The original single-wheel workflow still works exactly as before:

```bash
# Build and publish single variant
./test_and_publish.sh --variant=vllm-cpu-avx512vnni

# Or use existing wheel
./test_and_publish.sh --variant=vllm-cpu-avx512vnni --skip-build
```

---

## Mode Detection Logic

The script automatically enables multi-wheel mode when:

1. **`--variant=all`** is specified
2. **`--skip-build`** is used (processes all wheels in dist/)

Otherwise, single-wheel mode is used.

### Multi-Wheel Mode
- Finds ALL wheels in `dist/` directory
- Validates ALL wheels
- Tests ALL packages from TestPyPI
- Publishes ALL wheels to PyPI
- **Skips GitHub releases** (too many variants)

### Single-Wheel Mode
- Finds specific variant wheel
- Validates single wheel
- Tests single package from TestPyPI
- Publishes single wheel to PyPI
- **Creates GitHub release** (single variant)

---

## Comparison Table

| Feature | Single-Wheel Mode | Multi-Wheel Mode |
|---------|------------------|------------------|
| **Trigger** | `--variant=<name>` | `--variant=all` or `--skip-build` |
| **Wheels Processed** | 1 | All in dist/ |
| **Validation** | Single wheel | All wheels |
| **TestPyPI Testing** | Single package | All packages |
| **PyPI Publishing** | Single wheel | All wheels |
| **GitHub Release** | ✅ Created | ❌ Skipped |
| **Time Required** | 30-60 min + build | 1-2 hours + build |

---

## Installation Testing Details

### Single-Wheel Mode
- Creates ONE test environment
- Installs ONE package from TestPyPI
- Verifies vLLM import
- Checks vLLM version
- Verifies PyTorch integration
- Detailed output for debugging

### Multi-Wheel Mode
- Creates SEPARATE test environment for EACH package
- Tests ALL packages independently
- Prevents conflicts between variants
- Faster per-package testing (less verbose)
- Summary at the end

**Multi-Wheel Test Output:**
```
2025-11-21 19:00:30 [INFO] Testing installation of 5 package(s) from Test PyPI...
2025-11-21 19:00:30 [INFO] ==========================================
2025-11-21 19:00:30 [INFO] Testing package 1/5: vllm-cpu
2025-11-21 19:00:30 [INFO] ==========================================
2025-11-21 19:00:35 [SUCCESS] ✓ vllm-cpu: vLLM 0.6.3 installed and working
2025-11-21 19:00:35 [INFO] ==========================================
2025-11-21 19:00:35 [INFO] Testing package 2/5: vllm-cpu-avx512
2025-11-21 19:00:35 [INFO] ==========================================
2025-11-21 19:00:40 [SUCCESS] ✓ vllm-cpu-avx512: vLLM 0.6.3 installed and working
...
2025-11-21 19:01:00 [SUCCESS] All 5 package(s) tested successfully
```

---

## GitHub Release Handling

### Why Skipped in Multi-Wheel Mode?

1. **Too many releases**: 5 releases at once clutters the repository
2. **Different tags**: Each variant needs a unique tag (v0.6.3-vllm-cpu, v0.6.3-vllm-cpu-avx512, etc.)
3. **Better workflow**: Create releases individually after verifying production PyPI

### Creating Individual Releases

After publishing all wheels to PyPI, create releases one by one:

```bash
# Method 1: Use test_and_publish.sh for each variant
for variant in vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16; do
  ./test_and_publish.sh --variant=$variant --skip-build --skip-test-pypi
done

# Method 2: Use gh cli directly
gh release create v0.6.3-vllm-cpu --title "vLLM CPU v0.6.3" dist/vllm_cpu-0.6.3-*.whl
gh release create v0.6.3-vllm-cpu-avx512 --title "vLLM CPU AVX512 v0.6.3" dist/vllm_cpu_avx512-0.6.3-*.whl
# ... etc
```

---

## Error Handling

### Validation Failures
If any wheel fails validation, the entire process stops:

```
2025-11-21 19:00:05 [ERROR] Validation failed for dist/vllm_cpu_broken-0.6.3-*.whl
2025-11-21 19:00:05 [ERROR] Some wheels failed validation
```

**Fix**: Remove or fix the broken wheel and re-run

### Installation Test Failures
If any package fails to install from TestPyPI:

```
2025-11-21 19:00:35 [ERROR] Failed to install vllm-cpu-avx512 from Test PyPI
2025-11-21 19:00:35 [ERROR] Some package tests failed
```

**Possible causes**:
- Package not yet available on TestPyPI (wait 30 seconds)
- Network issues
- Dependency conflicts

---

## Prerequisites

### Required
- ✅ `python3` (version 3.9+)
- ✅ `twine` (for wheel validation)
- ✅ `pip` (for installation testing)
- ✅ PyPI API tokens in `.env` or environment

### Optional
- `gh` (GitHub CLI) - only needed for GitHub releases

---

## API Token Setup

### Create `.env` file:
```bash
cat > .env <<'EOF'
PYPI_API_TOKEN=pypi-your-production-token
TEST_PYPI_API_TOKEN=pypi-your-test-token
EOF

chmod 600 .env
```

### Or use environment variables:
```bash
export PYPI_API_TOKEN="pypi-your-production-token"
export TEST_PYPI_API_TOKEN="pypi-your-test-token"
```

---

## Performance

### Single-Wheel Mode
- **Build time**: 30-60 minutes (per variant)
- **Validation**: <1 minute
- **TestPyPI publish**: 1-2 minutes
- **Installation test**: 2-3 minutes
- **Production publish**: 1-2 minutes
- **GitHub release**: <1 minute
- **Total**: 35-70 minutes

### Multi-Wheel Mode (5 variants)
- **Build time**: 2.5-5 hours (all variants)
- **Validation**: 1-2 minutes (all wheels)
- **TestPyPI publish**: 2-3 minutes (all wheels)
- **Installation tests**: 10-15 minutes (all packages, parallel)
- **Production publish**: 2-3 minutes (all wheels)
- **GitHub releases**: Skipped (create manually)
- **Total**: 3-6 hours

---

## Best Practices

### 1. Always Test on TestPyPI First
```bash
# DON'T skip TestPyPI in production
./test_and_publish.sh --variant=all --skip-test-pypi  # ❌ Risky

# DO test on TestPyPI first
./test_and_publish.sh --variant=all  # ✅ Safe
```

### 2. Use Dry-Run for New Workflows
```bash
# Test the workflow before real publish
./test_and_publish.sh --variant=all --dry-run
```

### 3. Build All Variants Separately First
```bash
# Build all variants first (can monitor progress)
./build_wheels.sh --variant=all

# Then test and publish (faster feedback)
./test_and_publish.sh --skip-build
```

### 4. Keep Wheels Organized
```bash
# Use dated output directories
./build_wheels.sh --variant=all --output-dir=./dist/2025-11-21

# Then publish from that directory
cd dist/2025-11-21
../../test_and_publish.sh --skip-build
```

---

## Troubleshooting

### Issue 1: "No wheels found in dist/"

**Cause**: dist/ directory is empty

**Solution**:
```bash
# Check dist/ contents
ls -lh dist/

# Build wheels first
./build_wheels.sh --variant=all
```

### Issue 2: "Some wheels failed validation"

**Cause**: Malformed wheel files

**Solution**:
```bash
# Check which wheel failed
twine check dist/*.whl

# Rebuild that specific variant
./build_wheels.sh --variant=vllm-cpu-<problematic-variant>
```

### Issue 3: "Failed to install from Test PyPI"

**Cause**: Package not yet available (TestPyPI needs time to process)

**Solution**:
```bash
# Wait 60 seconds and try again
sleep 60
./test_and_publish.sh --skip-build --skip-test-pypi  # Skip TestPyPI, go straight to production
```

### Issue 4: Production publish requires confirmation

**Expected behavior**: The script asks for confirmation before production publish

**To automate** (use with caution):
```bash
# Auto-confirm (NOT RECOMMENDED)
echo "yes" | ./test_and_publish.sh --skip-build
```

---

## Migration from v1.0.0

### v1.0.0 (Old)
```bash
# Had to publish each variant individually
./test_and_publish.sh --variant=vllm-cpu
./test_and_publish.sh --variant=vllm-cpu-avx512
./test_and_publish.sh --variant=vllm-cpu-avx512vnni
./test_and_publish.sh --variant=vllm-cpu-avx512bf16
./test_and_publish.sh --variant=vllm-cpu-amxbf16
```

### v2.0.0 (New)
```bash
# Publish all variants in one command
./build_wheels.sh --variant=all
./test_and_publish.sh --skip-build
```

**Benefits**:
- ✅ 80% less commands to run
- ✅ Single confirmation prompt
- ✅ Batch validation
- ✅ Parallel testing
- ✅ Consistent workflow

---

## Summary

### Key Features
✅ **Multi-wheel support**: Process all 5 variants at once
✅ **Backward compatible**: Single-wheel mode unchanged
✅ **Smart detection**: Auto-enables multi-wheel when appropriate
✅ **Batch operations**: Validate and test all wheels together
✅ **Separate testing**: Each package tested in isolation
✅ **Flexible workflow**: Support for `--variant=all` and `--skip-build`

### Typical Workflow
```bash
# 1. Build all variants
./build_wheels.sh --variant=all

# 2. Test with dry-run first
./test_and_publish.sh --skip-build --dry-run

# 3. Publish all to PyPI
./test_and_publish.sh --skip-build

# 4. Create GitHub releases individually (optional)
for variant in vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16; do
  ./test_and_publish.sh --variant=$variant --skip-build --skip-test-pypi
done
```

---

**Version**: 2.0.0
**Date**: 2025-11-21
**Status**: ✅ Implemented and Tested
