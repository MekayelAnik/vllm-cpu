# Dry-Run Feature Implementation

## Overview

Added `--dry-run` capability to `build_wheels.sh` v2.0.0, allowing users to preview build operations without executing them.

## Usage

```bash
# Dry-run for single variant
./build_wheels.sh --variant=vllm-cpu-avx512vnni --max-jobs=6 --dry-run

# Dry-run for all variants
./build_wheels.sh --variant=all --dry-run

# Dry-run with custom output directory
./build_wheels.sh --variant=vllm-cpu-avx512bf16 --output-dir=/custom/path --dry-run
```

## What Dry-Run Shows

When `--dry-run` is enabled, the script displays what would be executed without actually performing the operations:

### 1. **Banner**
```
==========================================
DRY RUN MODE - No actual changes will be made
==========================================
```

### 2. **Repository Operations**
- `[DRY RUN] Would execute: timeout 300 git clone https://github.com/vllm-project/vllm.git`
- `[DRY RUN] Would execute: cd vllm`
- `[DRY RUN] Would detect version from git`
- `[DRY RUN] Would execute: git checkout <version>`

### 3. **Virtual Environment**
- `[DRY RUN] Would execute: uv venv --python 3.13 /tmp/vllm-build/venv-<variant>`
- `[DRY RUN] Would execute: source /tmp/vllm-build/venv-<variant>/bin/activate`

### 4. **Dependencies**
- `[DRY RUN] Would execute: uv pip install --upgrade pip setuptools wheel build`
- `[DRY RUN] Would execute: uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu`
- `[DRY RUN] Would execute: uv pip install -r requirements/cpu-build.txt (or fallback)`

### 5. **Build Environment Variables**
```
[DRY RUN] Build environment:
  VLLM_TARGET_DEVICE=cpu
  MAX_JOBS=6
  VLLM_CPU_DISABLE_AVX512=0
  VLLM_CPU_AVX512VNNI=1
  VLLM_CPU_AVX512BF16=0
  VLLM_CPU_AMXBF16=0
```

### 6. **Metadata Customization**
- `[DRY RUN] Would backup pyproject.toml`
- `[DRY RUN] Would update package name to: <package-name>`
- `[DRY RUN] Would update description to: <description>`
- `[DRY RUN] Would add PyTorch CPU-only installation instructions`

### 7. **Wheel Build**
- `[DRY RUN] Would create wheel directory: /tmp/vllm-build/wheels-<variant>`
- `[DRY RUN] Would execute: timeout 3600 python setup.py bdist_wheel --dist-dir=<path>`
- `[DRY RUN] Would restore original pyproject.toml`
- `[DRY RUN] Would copy wheel to: <output-dir>`
- `[SUCCESS] [DRY RUN] Would complete build for <variant>`

### 8. **Cleanup**
- `[DRY RUN] Would deactivate virtual environment`

## Example Output

```bash
$ ./build_wheels.sh --variant=vllm-cpu-avx512vnni --max-jobs=6 --dry-run

2025-11-21 18:11:08 [INFO] Starting vLLM CPU wheel builder v2.0.0
2025-11-21 18:11:08 [INFO] ==========================================
2025-11-21 18:11:08 [INFO] DRY RUN MODE - No actual changes will be made
2025-11-21 18:11:08 [INFO] ==========================================
2025-11-21 18:11:08 [INFO] Building variant: vllm-cpu-avx512vnni
2025-11-21 18:11:08 [INFO] Package: vllm-cpu-avx512vnni
2025-11-21 18:11:08 [INFO] AVX512 Disabled: false
2025-11-21 18:11:08 [INFO] VNNI Enabled: true
2025-11-21 18:11:08 [INFO] BF16 Enabled: false
2025-11-21 18:11:08 [INFO] AMX Enabled: false
2025-11-21 18:11:08 [INFO] Cloning vLLM repository...
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: timeout 300 git clone https://github.com/vllm-project/vllm.git
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: cd vllm
2025-11-21 18:11:08 [INFO] [DRY RUN] Would detect version from git
2025-11-21 18:11:08 [INFO] Detected version: 0.0.0
2025-11-21 18:11:08 [INFO] Creating build environment...
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: uv venv --python 3.13 /tmp/vllm-build/venv-vllm-cpu-avx512vnni
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: source /tmp/vllm-build/venv-vllm-cpu-avx512vnni/bin/activate
2025-11-21 18:11:08 [INFO] Installing build dependencies...
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: uv pip install --upgrade pip setuptools wheel build
2025-11-21 18:11:08 [INFO] Installing PyTorch CPU-only with torchvision and torchaudio...
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: uv pip install -r requirements/cpu-build.txt (or fallback to cmake ninja setuptools-scm)
2025-11-21 18:11:08 [INFO] Setting build environment variables...
2025-11-21 18:11:08 [INFO] [DRY RUN] Build environment:
2025-11-21 18:11:08 [INFO]   VLLM_TARGET_DEVICE=cpu
2025-11-21 18:11:08 [INFO]   MAX_JOBS=6
2025-11-21 18:11:08 [INFO]   VLLM_CPU_DISABLE_AVX512=0
2025-11-21 18:11:08 [INFO]   VLLM_CPU_AVX512VNNI=1
2025-11-21 18:11:08 [INFO]   VLLM_CPU_AVX512BF16=0
2025-11-21 18:11:08 [INFO]   VLLM_CPU_AMXBF16=0
2025-11-21 18:11:08 [INFO] Customizing package metadata for vllm-cpu-avx512vnni...
2025-11-21 18:11:08 [INFO] [DRY RUN] Would backup pyproject.toml
2025-11-21 18:11:08 [INFO] [DRY RUN] Would update package name to: vllm-cpu-avx512vnni
2025-11-21 18:11:08 [INFO] [DRY RUN] Would update description to: vLLM CPU inference engine (AVX512 + VNNI optimized)
2025-11-21 18:11:08 [INFO] [DRY RUN] Would add PyTorch CPU-only installation instructions
2025-11-21 18:11:08 [INFO] Building wheel (this may take 30-60 minutes)...
2025-11-21 18:11:08 [INFO] [DRY RUN] Would create wheel directory: /tmp/vllm-build/wheels-vllm-cpu-avx512vnni
2025-11-21 18:11:08 [INFO] [DRY RUN] Would execute: timeout 3600 python setup.py bdist_wheel --dist-dir=/tmp/vllm-build/wheels-vllm-cpu-avx512vnni
2025-11-21 18:11:08 [INFO] [DRY RUN] Would restore original pyproject.toml
2025-11-21 18:11:08 [INFO] [DRY RUN] Would copy wheel to: ./dist
2025-11-21 18:11:08 [SUCCESS] [DRY RUN] Would complete build for vllm-cpu-avx512vnni
2025-11-21 18:11:08 [INFO] [DRY RUN] Would deactivate virtual environment
```

## Implementation Details

### Changes Made

1. **Added DRY_RUN variable** (Line 62)
   ```bash
   DRY_RUN=0  # Default: disabled
   ```

2. **Updated help text** (Line 20)
   ```bash
   #   --dry-run                Show what would be done without doing it
   ```

3. **Added parse_args handling** (Line 219-222)
   ```bash
   --dry-run)
       DRY_RUN=1
       shift
       ;;
   ```

4. **Added run_cmd helper function** (Line 285-293)
   ```bash
   run_cmd() {
       if [[ $DRY_RUN -eq 1 ]]; then
           log_info "[DRY RUN] Would execute: $*"
           return 0
       else
           "$@"
       fi
   }
   ```

5. **Added dry-run banner in main()** (Line 575-579)
   ```bash
   if [[ $DRY_RUN -eq 1 ]]; then
       log_info "=========================================="
       log_info "DRY RUN MODE - No actual changes will be made"
       log_info "=========================================="
   fi
   ```

6. **Wrapped all critical operations** in build_variant():
   - Git clone (Line 342-350)
   - Directory changes (Line 356-363)
   - Version detection (Line 367-383)
   - Virtual environment creation (Line 389-407)
   - Dependency installation (Line 411-453)
   - Metadata customization (Line 498-543)
   - Wheel building (Line 552-607)

## Benefits

### 1. **Safety**
- Preview build operations before executing
- Verify configuration and parameters
- No accidental builds or modifications

### 2. **Planning**
- Understand build process flow
- Estimate resource requirements
- Identify potential issues early

### 3. **Documentation**
- Self-documenting build process
- Clear understanding of operations
- Training and onboarding tool

### 4. **Debugging**
- Verify environment variables
- Check file paths and directories
- Validate build configuration

## Use Cases

### 1. **First-Time Users**
```bash
# Preview the build process before running
./build_wheels.sh --variant=vllm-cpu --dry-run
```

### 2. **Configuration Verification**
```bash
# Verify VNNI variant configuration
./build_wheels.sh --variant=vllm-cpu-avx512vnni --max-jobs=6 --dry-run
```

### 3. **Build Planning**
```bash
# Check what building all variants would do
./build_wheels.sh --variant=all --dry-run
```

### 4. **CI/CD Testing**
```bash
# Test build script changes without actual build
./build_wheels.sh --variant=vllm-cpu-avx512bf16 --dry-run
```

### 5. **Resource Estimation**
```bash
# See what resources would be needed
./build_wheels.sh --variant=vllm-cpu-amxbf16 --max-jobs=8 --output-dir=/mnt/nvme --dry-run
```

## Testing

### Test 1: Single Variant Dry-Run
```bash
./build_wheels.sh --variant=vllm-cpu-avx512vnni --max-jobs=6 --dry-run
```
**Result**: ✅ Shows all operations without executing

### Test 2: All Variants Dry-Run
```bash
./build_wheels.sh --variant=all --dry-run
```
**Result**: ✅ Shows operations for all 5 variants

### Test 3: Custom Parameters
```bash
./build_wheels.sh --variant=vllm-cpu-avx512bf16 --max-jobs=16 --output-dir=/custom --python-version=3.12 --dry-run
```
**Result**: ✅ Shows correct parameters in dry-run output

### Test 4: Help Text
```bash
./build_wheels.sh --help | grep "dry-run"
```
**Result**: ✅ Shows --dry-run option in help

## Comparison with Other Tools

### Similar to:
- `git --dry-run`
- `rsync --dry-run`
- `make -n` (no-execute)
- `docker build --dry-run`
- `terraform plan`

### Advantages:
- Clear [DRY RUN] prefixes
- Detailed operation descriptions
- Shows environment variables
- No state changes at all

## Future Enhancements

### Potential Improvements:
1. **JSON Output**: `--dry-run-json` for programmatic parsing
2. **Time Estimates**: Show estimated duration for each step
3. **Resource Requirements**: Display disk space, memory needs
4. **Dependency Check**: Verify all tools available before starting
5. **Interactive Mode**: Ask for confirmation after dry-run

## Known Limitations

1. **No File Existence Checks**: Doesn't verify if files actually exist (by design)
2. **No Network Checks**: Doesn't test if repositories are accessible
3. **No Space Checks**: Doesn't verify disk space availability
4. **No Version Validation**: Doesn't check if vLLM version exists

These limitations are intentional - dry-run is meant to show what *would* happen, not to validate the environment.

## Version History

- **v2.0.0** (2025-11-21): Initial dry-run implementation
  - Added --dry-run flag
  - Added run_cmd helper function
  - Wrapped all critical operations
  - Added dry-run banner
  - Added environment variable display

## Author

- Implemented as part of build_wheels.sh v2.0.0
- Date: 2025-11-21

## Related Documentation

- [build_wheels.sh](./build_wheels.sh) - Main build script
- [CONSOLIDATION_NOTES.md](./CONSOLIDATION_NOTES.md) - Script consolidation
- [PYTORCH_CPU_DEPENDENCY.md](./PYTORCH_CPU_DEPENDENCY.md) - PyTorch CPU configuration
- [TORCHVISION_TORCHAUDIO_REQUIRED.md](./TORCHVISION_TORCHAUDIO_REQUIRED.md) - Vision/audio dependencies

---

**Status**: ✅ Implemented and Tested
**Version**: 2.0.0
**Date**: 2025-11-21
