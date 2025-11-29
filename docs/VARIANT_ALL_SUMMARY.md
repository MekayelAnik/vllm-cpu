# --variant=all Feature Summary

## What Changed

Added support for `--variant=all` to build all 5 wheel variants in a single command.

## Usage

```bash
# Three equivalent ways to build all variants:

# Method 1: Explicit --variant=all
./build_wheels.sh --variant=all

# Method 2: No variant specified (default behavior)
./build_wheels.sh

# Method 3: Enhanced script
./build_wheels_enhanced.sh --variant=all
```

## Features

✅ **Builds all 5 variants sequentially**:
- vllm-cpu
- vllm-cpu-avx512
- vllm-cpu-avx512vnni
- vllm-cpu-avx512bf16
- vllm-cpu-amxbf16

✅ **Benefits**:
- Single command for complete build
- Consistent build environment
- Automatic cleanup between variants
- Progress logging for each variant
- Error handling per variant

✅ **Time estimate**: 2.5-5 hours total

## Examples

### Basic

```bash
./build_wheels.sh --variant=all
```

### With Options

```bash
./build_wheels.sh \
  --variant=all \
  --vllm-version=v0.6.3 \
  --max-jobs=8 \
  --python-version=3.13
```

### Enhanced Version (Recommended)

```bash
# With timestamps and better logging
./build_wheels_enhanced.sh --variant=all
```

## Output

```bash
$ ./build_wheels.sh --variant=all

[INFO] Building all 5 variants (this will take 2.5-5 hours)...
========================================
[INFO] Building variant: vllm-cpu
[INFO] Package: vllm-cpu
...
[SUCCESS] Built wheel for vllm-cpu
========================================

========================================
[INFO] Building variant: vllm-cpu-avx512
...
[SUCCESS] Built wheel for vllm-cpu-avx512
========================================

... (continues for all 5 variants)

[SUCCESS] All variants built successfully!
[INFO] Built wheels:
-rw-r--r-- vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- vllm_cpu_avx512-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- vllm_cpu_avx512vnni-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- vllm_cpu_avx512bf16-0.6.3-cp313-cp313-linux_x86_64.whl
-rw-r--r-- vllm_cpu_amxbf16-0.6.3-cp313-cp313-linux_x86_64.whl
```

## Files Modified

1. `build_wheels.sh` - Added --variant=all support
2. `build_wheels_enhanced.sh` - Added --variant=all support
3. `CLAUDE.md` - Updated documentation
4. `BUILD_ALL_VARIANTS.md` - Complete guide (NEW)
5. `VARIANT_ALL_SUMMARY.md` - This file (NEW)

## Documentation

See `BUILD_ALL_VARIANTS.md` for comprehensive documentation including:
- Detailed usage examples
- Time estimates
- Resource requirements
- Troubleshooting guide
- Performance tips
- Post-build actions

## Quick Reference

| Command | Result |
|---------|--------|
| `./build_wheels.sh` | Builds all 5 variants |
| `./build_wheels.sh --variant=all` | Builds all 5 variants (explicit) |
| `./build_wheels.sh --variant=vllm-cpu` | Builds only vllm-cpu |
| Time per variant | 30-60 minutes |
| Total time (all) | 2.5-5 hours |
| Output size | ~1.2GB (5 wheels) |

## Backward Compatibility

✅ **Fully backward compatible**

- Existing commands work unchanged
- `./build_wheels.sh` still builds all (default behavior preserved)
- Single variant builds unchanged: `--variant=vllm-cpu-avx512`
- All options work with `--variant=all`

## Testing

```bash
# Test help
./build_wheels.sh --help | grep variant

# Expected output includes:
#   --variant=NAME           Build specific variant (vllm-cpu, vllm-cpu-avx512, etc.)
#                            Use --variant=all to build all 5 variants

# Test dry run (with non-existent version to fail fast)
./build_wheels.sh --variant=all --vllm-version=v0.0.0
# Should show "Building all 5 variants..." message
```

## Integration

### CI/CD

```yaml
# GitHub Actions
- name: Build all variants
  run: ./build_wheels.sh --variant=all
  timeout-minutes: 360
```

### Scripts

```bash
#!/bin/bash
# build_and_publish.sh

set -e

# Build all
./build_wheels.sh --variant=all

# Validate all
for wheel in dist/*.whl; do
    twine check "$wheel"
done

# Publish all
./publish_to_pypi.sh --test --skip-build
```

## When to Use

**Use `--variant=all` when:**
- ✅ Preparing PyPI release
- ✅ Building complete distribution
- ✅ You have 2.5-5 hours
- ✅ Need all CPU optimizations

**Use specific variant when:**
- ✅ Testing single optimization
- ✅ Limited time
- ✅ Only need one CPU type
- ✅ Iterating during development

---

**Version**: 2.0.0
**Date**: 2025-11-21
**Status**: ✅ Implemented and Tested
