# Project Directory Structure

## Overview

The build system now uses the project directory (`./build`) instead of `/tmp` for all build artifacts, making everything more organized and easier to manage.

## Version

**Changed in**: v2.1.0
**Date**: 2025-11-21

---

## Directory Structure

```
vllm-cpu/                          # Project root
├── build/                         # Build workspace (preserved, in .gitignore)
│   ├── vllm/                      # vLLM git repository (preserved between builds)
│   │   ├── .git/                  # Git metadata
│   │   ├── vllm/                  # vLLM source code
│   │   ├── setup.py
│   │   ├── pyproject.toml
│   │   └── ...
│   ├── venv-vllm-cpu/             # Virtual env for vllm-cpu variant (cleaned)
│   ├── venv-vllm-cpu-avx512/      # Virtual env for avx512 variant (cleaned)
│   ├── venv-vllm-cpu-avx512vnni/  # Virtual env for vnni variant (cleaned)
│   ├── wheels-vllm-cpu/           # Temporary wheels for vllm-cpu (cleaned)
│   └── wheels-vllm-cpu-avx512/    # Temporary wheels for avx512 (cleaned)
├── dist/                          # Final wheel output (user-accessible)
│   ├── vllm_cpu-0.6.3-*.whl
│   ├── vllm_cpu_avx512-0.6.3-*.whl
│   └── ...
├── build_wheels.sh                # Build script
├── publish_to_pypi.sh             # Publish script
├── test_and_publish.sh            # Test and publish script
├── build_config.json              # Build configuration
└── .gitignore                     # Git ignore rules
```

---

## What Changed

### Before (v2.0.0)
```
/tmp/vllm-build/                   # Temporary location
├── vllm/                          # vLLM repository
├── venv-*/                        # Virtual environments
└── wheels-*/                      # Temporary wheels

Issues:
❌ Lost on system reboot
❌ Hard to find and inspect
❌ Not in project directory
❌ Shared with other users
```

### After (v2.1.0)
```
./build/                           # Project directory
├── vllm/                          # vLLM repository (PRESERVED)
├── venv-*/                        # Virtual environments (CLEANED)
└── wheels-*/                      # Temporary wheels (CLEANED)

Benefits:
✅ Survives reboots
✅ Easy to find and inspect
✅ In project directory
✅ Private to this project
✅ In .gitignore (not pushed to repo)
```

---

## Benefits

### 1. Survives Reboots
- `/tmp` is often cleared on reboot
- `./build` persists across reboots
- vLLM repository never needs re-cloning after reboot

### 2. Easy Access
```bash
# Before: Hard to remember path
cd /tmp/vllm-build/vllm

# After: Simple relative path
cd build/vllm
```

### 3. Project Organization
- Everything in one place
- Easy to understand structure
- Clear separation of concerns

### 4. Git Integration
- Added `build/` to `.gitignore`
- Won't be pushed to repository
- Clean git status

### 5. Better for Development
```bash
# Check vLLM version
cd build/vllm
git log --oneline -5

# Test local changes
cd build/vllm
# Make changes
cd ../..
./build_wheels.sh --variant=vllm-cpu
```

---

## Cleanup Behavior

### What Gets Preserved ✅
```
build/vllm/                        # Entire vLLM repository
  ├── .git/                        # All git history
  ├── vllm/                        # Source code
  └── ...                          # All files
```

### What Gets Cleaned ❌
```
build/venv-*                       # Virtual environments
build/wheels-*                     # Temporary wheels
build/*                            # All other artifacts
```

---

## Usage Examples

### Normal Build
```bash
# First time: clones to ./build/vllm
./build_wheels.sh --variant=vllm-cpu

# Creates:
# ./build/vllm/                    (preserved)
# ./build/venv-vllm-cpu/           (cleaned after)
# ./build/wheels-vllm-cpu/         (cleaned after)
# ./dist/vllm_cpu-0.6.3-*.whl     (final output)
```

### Subsequent Builds
```bash
# Uses existing ./build/vllm (git pull to update)
./build_wheels.sh --variant=vllm-cpu

# Updates:
# ./build/vllm/                    (git pull)
# Recreates:
# ./build/venv-vllm-cpu/           (fresh venv)
# ./build/wheels-vllm-cpu/         (new wheels)
# Outputs:
# ./dist/vllm_cpu-0.6.3-*.whl     (final wheel)
```

### Check vLLM Repository
```bash
# Navigate to repository
cd build/vllm

# Check version
git describe --tags

# Check recent changes
git log --oneline -10

# Check branch
git branch -a

# Return to project root
cd ../..
```

### Manual Repository Management
```bash
# Update vLLM manually
cd build/vllm
git pull

# Checkout specific version
git checkout v0.6.3

# Return to latest
git checkout main
git pull

# Return to project
cd ../..
```

---

## Disk Space

### Location
```
./build/                           # ~1-2GB total
├── vllm/                          # ~800MB (persistent)
├── venv-vllm-cpu/                 # ~300MB (during build only)
└── wheels-vllm-cpu/               # ~100MB (during build only)

./dist/                            # ~100-500MB
└── *.whl                          # Final wheels
```

### After Cleanup
```
./build/                           # ~800MB
└── vllm/                          # ~800MB (preserved)

./dist/                            # ~100-500MB
└── *.whl                          # Final wheels
```

---

## .gitignore Configuration

Added to `.gitignore`:
```gitignore
# Build workspace (vLLM repository and build artifacts)
build/
```

This ensures:
- ✅ `build/` directory not tracked by git
- ✅ vLLM repository not pushed to your repo
- ✅ Clean `git status` output
- ✅ Smaller repository size

---

## Migration from v2.0.0

### Automatic Migration
The script automatically handles the change:

1. **First build after update**: Clones to `./build/vllm` (not `/tmp/vllm-build/vllm`)
2. **Old `/tmp` location**: Ignored, will be cleaned by system
3. **No manual migration needed**: Just run the build script

### Manual Cleanup (Optional)
```bash
# Remove old temporary build directory
rm -rf /tmp/vllm-build

# Old directory will be ignored from now on
```

---

## Multiple Projects

### Before (Conflict Risk)
```
/tmp/vllm-build/                   # Shared between all projects
├── vllm/                          # Can conflict between projects
└── ...
```

### After (Isolated)
```
project-1/build/vllm/              # Project 1's vLLM
project-2/build/vllm/              # Project 2's vLLM
project-3/build/vllm/              # Project 3's vLLM
```

Each project has its own:
- ✅ vLLM repository
- ✅ Virtual environments
- ✅ Build artifacts

No conflicts between projects!

---

## Workspace Variable

You can still override the workspace location:

```bash
# Use custom workspace
WORKSPACE=/custom/path ./build_wheels.sh --variant=vllm-cpu

# Use temporary location (old behavior)
WORKSPACE=/tmp/vllm-build ./build_wheels.sh --variant=vllm-cpu
```

But we recommend using the default (`./build`).

---

## Common Operations

### Inspect Build Directory
```bash
# List contents
ls -lh build/

# Check sizes
du -sh build/*

# Check vLLM repository
cd build/vllm
git status
git log --oneline -5
cd ../..
```

### Clean Everything
```bash
# Clean build artifacts only (preserves vLLM repo)
rm -rf build/venv-* build/wheels-*

# Clean everything including vLLM repo
rm -rf build/

# Next build will clone fresh
./build_wheels.sh --variant=vllm-cpu
```

### Backup vLLM Repository
```bash
# Backup before major changes
cp -r build/vllm build/vllm.backup

# Restore if needed
rm -rf build/vllm
mv build/vllm.backup build/vllm
```

---

## Troubleshooting

### Issue 1: "Permission Denied"
```bash
# Check permissions
ls -ld build/

# Fix permissions
chmod 755 build/
chmod -R u+rw build/
```

### Issue 2: "No Space Left on Device"
```bash
# Check disk space
df -h .

# Clean old artifacts
rm -rf build/venv-* build/wheels-*

# Or clean everything
rm -rf build/
```

### Issue 3: "Directory Not Found"
```bash
# The script creates it automatically, but if you get this error:
mkdir -p build/
./build_wheels.sh --variant=vllm-cpu
```

### Issue 4: "Git Repository Corrupted"
```bash
# Remove corrupted repository
rm -rf build/vllm

# Next build will clone fresh
./build_wheels.sh --variant=vllm-cpu
```

---

## Performance

### No Performance Change
The location change doesn't affect build performance:

- **Clone speed**: Same (network-bound)
- **Build speed**: Same (CPU/disk-bound)
- **Git pull speed**: Same (network-bound)

### Potential Benefits
On some systems, project directory may be:
- ✅ On faster disk (SSD vs HDD)
- ✅ With better I/O scheduler
- ✅ Not subject to tmpfs size limits

---

## Security

### Before
```
/tmp/vllm-build/                   # World-readable
├── vllm/                          # Other users can access
└── venv-*/                        # Shared tmp directory
```

### After
```
./build/                           # Project permissions
├── vllm/                          # Controlled by project owner
└── venv-*/                        # Project directory permissions
```

Better security:
- ✅ Project-level permissions
- ✅ Not in shared `/tmp`
- ✅ Controlled access

---

## Best Practices

### DO ✅
- ✅ Use default `./build` location
- ✅ Let cleanup preserve `build/vllm/`
- ✅ Add `build/` to `.gitignore` (already done)
- ✅ Inspect `build/vllm/` when debugging

### DON'T ❌
- ❌ Don't manually delete `build/vllm/` (unless needed)
- ❌ Don't commit `build/` to git (in .gitignore)
- ❌ Don't modify files in `build/venv-*/` directly
- ❌ Don't assume `/tmp/vllm-build` still exists

---

## Summary

### Key Changes
1. **Workspace location**: `/tmp/vllm-build` → `./build`
2. **Git repository**: `./build/vllm/` (preserved)
3. **Virtual envs**: `./build/venv-*/` (cleaned)
4. **Final wheels**: `./dist/*.whl` (unchanged)

### Benefits
- ✅ Survives reboots
- ✅ Easy to access and manage
- ✅ Better project organization
- ✅ No conflicts between projects
- ✅ In .gitignore (clean repo)

### Trade-offs
- None! Pure improvement.

---

**Version**: 2.1.0
**Date**: 2025-11-21
**Status**: ✅ Implemented
