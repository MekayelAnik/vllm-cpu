# Build Script Cleanup Improvements

## Summary

Modified the vLLM wheel build scripts to **aggressively clean up temporary files and build artifacts after each individual wheel** is built. This ensures disk space is reclaimed immediately instead of accumulating throughout the build process.

**Now includes comprehensive cleanup of ALL cache directories** - workspace, uv cache, pip cache, and temporary files.

## Problem

Previously, the build process accumulated significant disk space in multiple locations:

### Workspace Directory
- **125MB** - CMake build artifacts in `build/vllm/build/`
- **5.6MB** - Virtual environment in `build/venv/`
- **~45KB each** - Multiple `.egg-info` directories
- Python cache files (`__pycache__`, `*.pyc`)

### Cache Directories (Hidden Accumulation)
- **~/.cache/uv/** - uv package manager cache (can grow to hundreds of MB)
- **~/.cache/pip/** - pip package cache
- **~/.local/share/uv/** - uv data directory
- **/tmp/** - Temporary build files (pip-*, tmp*vllm*, etc.)

These artifacts were only partially cleaned up at script exit, causing disk space to fill up when building multiple wheels.

## Solution

### Changes to `build_wheels.sh`

1. **New Function: `cleanup_after_wheel()`**
   - Runs **immediately after each wheel is built**
   - Removes workspace artifacts:
     - Virtual environment (`build/venv/`)
     - CMake build artifacts (`build/vllm/build/`)
     - All `.egg-info` directories
     - Python cache (`__pycache__/`, `*.pyc`, `*.pyo`)
     - Temporary wheel directory (`build/wheels-*`)
     - Git modifications and backup files
   - **NEW:** Cleans cache directories:
     - `uv cache clean` - removes uv package cache
     - `~/.cache/pip/*` - removes pip cache
     - `~/.local/share/uv/*` - removes uv data
     - `/tmp/pip-*`, `/tmp/tmp*vllm*`, etc. - removes temp files
   - Resets vLLM repository to clean state
   - **Reports disk space reclaimed** (typically ~130MB per wheel from workspace)
   - **Reports cache sizes** if they still exist

2. **Integration**
   - Called at the end of `build_variant()` function
   - Runs after wheel is copied to output directory
   - Runs before next wheel build starts
   - Ensures completely clean environment for next build

3. **Updated `cleanup()` function**
   - Now focuses on final cleanup at script exit
   - Per-wheel cleanup handles most of the work
   - Only removes remaining artifacts

### Changes to `build_multipy_wheels.sh`

Added comprehensive cleanup after `cibuildwheel` completes:
- Removes CMake build artifacts
- Removes `.egg-info` directories
- Removes Python cache
- Resets git repository to clean state
- **NEW:** Cleans uv cache, pip cache, temp files, and uv data directory

## What Gets Cleaned

After each wheel build, the following are removed:

### Workspace Directory
```
build/
├── venv/                    ← DELETED (5.6MB)
└── vllm/
    ├── build/               ← DELETED (125MB) - CMake artifacts
    ├── *.egg-info/          ← DELETED (~45KB each)
    ├── __pycache__/         ← DELETED - Python cache
    ├── *.pyc, *.pyo         ← DELETED - Compiled Python
    ├── *.backup             ← DELETED - Backup files
    └── .git                 ← PRESERVED (git reset --hard)
```

### Cache Directories
```
~/.cache/
├── uv/                      ← CLEANED - uv package cache
└── pip/                     ← CLEANED - pip package cache

~/.local/share/
└── uv/                      ← CLEANED - uv data directory

/tmp/
├── pip-*                    ← DELETED - pip temp files
├── tmp*vllm*               ← DELETED - vllm temp files
├── tmp*wheel*              ← DELETED - wheel temp files
└── tmp*build*              ← DELETED - build temp files
```

## What Gets Preserved

Only the vLLM git repository is preserved:
```
build/
└── vllm/                    ← PRESERVED
    └── .git/                ← Clean repository state
```

## Disk Space Impact

**Before:**
- Disk space accumulates with each wheel build
- Workspace: ~2GB+ for 15 wheels (5 variants × 3 Python versions)
- Cache directories: Additional hundreds of MB

**After:**
- ~130MB reclaimed from workspace after each wheel
- Cache directories cleaned after each wheel
- Workspace returns to baseline size (vLLM repo only: ~150MB)
- Net change: **+0MB** (except for output .whl files)

## Usage

### Normal Build (with cleanup)
```bash
./build_wheels.sh --variant=all --python-versions=3.10-3.13
```

### Disable Cleanup (for debugging)
```bash
./build_wheels.sh --variant=noavx512 --no-cleanup
```

### Dry Run (preview cleanup actions)
```bash
./build_wheels.sh --variant=avx512 --dry-run
```

### Verify Cleanup is Working
```bash
./verify_cleanup.sh
# Then run your build command when prompted
```

## Example Output

When cleanup runs, you'll see:

```
[INFO] Cleaning up build artifacts for vllm-cpu...
[INFO] Removing virtual environment...
[INFO] Removing CMake build artifacts...
[INFO] Removing .egg-info directories...
[INFO] Removing Python cache...
[INFO] Removing temporary wheel directory...
[INFO] Resetting vLLM repository to clean state...
[INFO] Cleaning uv cache...
[INFO] Cleaning pip cache...
[INFO] Cleaning temporary build files...
[INFO] Cleaning uv data directory...
[SUCCESS] Cleanup complete! Reclaimed 128MB of disk space (workspace only)
[INFO] Workspace size: 152M
[INFO] uv cache: 0B
[INFO] pip cache: 0B
```

## Benefits

1. **Prevents disk space exhaustion** during multi-wheel builds
2. **Immediate cleanup** after each wheel (not at script exit)
3. **Comprehensive** - cleans workspace AND cache directories
4. **Clean build environment** for each wheel (prevents artifact contamination)
5. **Transparent** - shows exactly how much space was reclaimed
6. **Preserves vLLM repo** - avoids expensive re-cloning
7. **Optional** - can be disabled with `--no-cleanup` flag
8. **Disk neutral** - disk usage before and after is the same (excluding .whl output)

## Testing and Verification

### Quick Manual Test

1. Check workspace size before build:
   ```bash
   du -sh build/
   ```

2. Build a single wheel:
   ```bash
   ./build_wheels.sh --variant=noavx512 --python-versions=3.12
   ```

3. Check workspace size after build:
   ```bash
   du -sh build/
   ```

4. Size should be nearly identical (except for the output .whl file)

### Automated Verification Script

Use the included verification script:

```bash
./verify_cleanup.sh
```

This script will:
- Measure disk usage before build
- Prompt you to run a build
- Measure disk usage after build
- Report on cleanup effectiveness
- Show PASS/FAIL for each location

**Expected Results:**
- ✓ PASS - Workspace change < 10MB
- ✓ PASS - uv cache change < 50MB
- ✓ PASS - pip cache change < 50MB
- ✓ PASS - Temp files cleaned up

## Locations Cleaned

| Location | What | Size | Frequency |
|----------|------|------|-----------|
| `build/venv/` | Virtual environment | ~5.6MB | After each wheel |
| `build/vllm/build/` | CMake artifacts | ~125MB | After each wheel |
| `build/vllm/*.egg-info/` | Egg metadata | ~45KB each | After each wheel |
| `build/vllm/__pycache__/` | Python cache | Varies | After each wheel |
| `build/wheels-*/` | Temp wheel dir | Varies | After each wheel |
| `~/.cache/uv/` | uv package cache | Varies | After each wheel |
| `~/.cache/pip/` | pip package cache | Varies | After each wheel |
| `~/.local/share/uv/` | uv data directory | Varies | After each wheel |
| `/tmp/pip-*` | pip temp files | Varies | After each wheel |
| `/tmp/tmp*vllm*` | vllm temp files | Varies | After each wheel |

## Troubleshooting

### If cleanup isn't working:

1. **Check if cleanup is disabled:**
   ```bash
   # Make sure you're not using --no-cleanup
   ./build_wheels.sh --variant=noavx512  # Good
   ./build_wheels.sh --variant=noavx512 --no-cleanup  # Bad
   ```

2. **Run verification script:**
   ```bash
   ./verify_cleanup.sh
   ```

3. **Check permissions:**
   ```bash
   # Ensure you can write to cache directories
   ls -la ~/.cache/
   ls -la ~/.local/share/
   ```

4. **Manual cleanup (if needed):**
   ```bash
   uv cache clean
   rm -rf ~/.cache/pip/*
   rm -rf ~/.local/share/uv/*
   rm -rf build/venv build/vllm/build build/vllm/*.egg-info
   ```

## Compatibility

- Works with all build variants (noavx512, avx512, avx512vnni, avx512bf16, amxbf16)
- Works with multiple Python versions (3.10-3.13)
- Works with multiple vLLM versions
- Compatible with `--dry-run` mode
- Respects `--no-cleanup` flag
- Safe to interrupt (cleanup runs after each wheel, not just at end)
