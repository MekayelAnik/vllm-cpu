# Changelog

All notable changes to the vLLM CPU wheel builder project will be documented in this file.

## [3.1.0] - 2025-11-28

### Added - Version Suffix Support for Re-uploading Deleted Wheels

PyPI has an immutable filename policy - once a filename is used (even if deleted), it cannot be re-uploaded. This release adds `--version-suffix` option to work around this limitation.

#### New Features
- **NEW**: `--version-suffix=SUFFIX` option in both `build_wheels.sh` and `test_and_publish.sh`
- **PEP 440 COMPLIANT**: Only `.postN` and `.devN` suffixes are supported (e.g., `.post1`, `.post2`, `.dev1`)
- Automatically validates suffix format for PEP 440 compliance
- **NEW**: Automatic wheel renaming when using `--skip-build` + `--version-suffix`
  - Extracts existing wheel, updates METADATA version, regenerates RECORD hashes, repackages
  - Avoids full rebuild when just renaming for re-upload

#### Usage
```bash
# Re-upload deleted wheel as 0.10.0.post1 (will rename existing wheels)
./test_and_publish.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --skip-build --version-suffix=.post1

# Build fresh wheel with version suffix
./build_wheels.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --version-suffix=.post1
```

#### Background
When you delete a wheel from PyPI and try to re-upload, you get:
```
ERROR HTTPError: 400 Bad Request from https://upload.pypi.org/legacy/
This filename was previously used by a file that has since been deleted.
```

The `--version-suffix` option creates a new version (e.g., `0.10.0.post1`) with a different filename, allowing upload to succeed.

#### Technical Details
- Only `.postN` and `.devN` are valid PEP 440 suffixes for PyPI uploads
- Local version identifiers (e.g., `+rebuild1`) are explicitly rejected by PyPI
- When renaming, the script:
  1. Extracts the wheel (ZIP file)
  2. Updates the `Version:` field in METADATA
  3. Renames the `.dist-info` directory
  4. Regenerates RECORD file with updated SHA256 hashes (base64-urlsafe encoded per PEP 427)
  5. Repackages as new wheel with new filename

#### Fixed - RECORD File Format
- **FIX**: RECORD file now uses base64-urlsafe encoded SHA256 hashes (PEP 427 compliant)
- Previous implementation used hex-encoded hashes which caused PyPI warnings
- Affects both `--version-suffix` (wheel renaming) and `--update-readme` operations
- PyPI warning was: "file contents do not match the included RECORD file"

#### Updated Documentation
- `docs/QUICK_REFERENCE.md` - Added re-upload workflow section
- `docs/TEST_AND_PUBLISH.md` - Added troubleshooting for deleted wheels

---

## [3.0.0] - 2025-11-28

### Changed - test_and_publish.sh (BREAKING)

#### Major Workflow Change: Build-Verify-Publish
- **BREAKING**: Removed Test PyPI verification workflow entirely
- **BREAKING**: Removed `--skip-test-pypi` argument
- **BREAKING**: Removed `--verify-only` / `--verify` arguments
- **BREAKING**: Removed `--test-in-docker` argument
- **BREAKING**: Removed `--test-docker-image` argument
- **NEW**: Simplified workflow: Build → Verify → Publish to Production PyPI
- **NEW**: Automatic wheel verification before publish
- **NEW**: Rebuild-on-verification-failure logic (max 2 attempts)

#### Removed Features
- `publish_to_test_pypi()` function - no more Test PyPI
- `test_installation()` function - replaced by file-based verification
- `test_package_in_docker()` function - no more Docker testing
- `test_all_installations_docker()` function - no more Docker testing
- `test_all_installations()` function - no more installation testing
- `get_test_python_version()` function - not needed without local testing
- `SKIP_TEST_PYPI` global variable
- `VERIFY_ONLY` global variable
- `TEST_IN_DOCKER` global variable
- `TEST_DOCKER_IMAGE` global variable
- `TEST_VENV` global variable
- `TEST_PYPI_API_TOKEN` environment variable support

#### New Workflow Phases
1. **Phase 0**: Pre-flight checks (PyPI status, local wheels)
2. **Phase 1**: Build and validate wheels
3. **Wheel Verification**: Automatic integrity checks
   - ZIP file integrity
   - Filename format (PEP 427)
   - `.dist-info` directory structure
   - Required files (METADATA, WHEEL, RECORD)
   - vllm module presence
   - `twine check` validation
4. **Phase 2**: Production PyPI publish (was Phase 3)
5. **Phase 3**: GitHub release (was Phase 4)

#### Rebuild-on-Failure Logic
- If wheel verification fails, automatically removes failed wheels
- Triggers rebuild immediately
- Re-verifies after rebuild
- Maximum 2 rebuild attempts before failing
- Prevents publishing corrupted or invalid wheels

#### Benefits
- ✅ Faster workflow (no Test PyPI round-trip)
- ✅ Simpler architecture (no virtual env setup for testing)
- ✅ More reliable (file-based verification is deterministic)
- ✅ Automatic recovery from build failures
- ✅ Reduced complexity (500+ lines of code removed)

#### Migration Guide
```bash
# Old (v2.x):
./test_and_publish.sh --variant=vllm-cpu --skip-test-pypi

# New (v3.x) - no Test PyPI option needed:
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0

# Old verify-only mode:
./test_and_publish.sh --verify-only --variant=vllm-cpu

# New - verification is automatic, just run with --dry-run to preview:
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --dry-run
```

#### Environment Variables Changed
- Removed: `TEST_PYPI_API_TOKEN` (no longer needed)
- Kept: `PYPI_API_TOKEN` or `PYPI_TOKEN` (for production PyPI)

### Updated Documentation
- `docs/TEST_AND_PUBLISH.md` - Complete rewrite for new workflow
- `docs/QUICK_REFERENCE.md` - Updated for v3.0.0
- Removed references to Test PyPI throughout documentation

---

## [2.2.0] - 2025-11-21

### Added - build_wheels.sh

#### Automatic Dependency Installation
- **NEW**: Automatic detection and installation of build dependencies
- **NEW**: `detect_distro()` function to identify Linux distribution
- **NEW**: `check_and_install_dependencies()` function for dependency management
- **NEW**: Support for multiple Linux distributions:
  - Ubuntu/Debian/Linux Mint/Pop!_OS (apt-get)
  - Fedora/RHEL/CentOS/Rocky/AlmaLinux (dnf)
  - openSUSE/SLES (zypper)
  - Arch Linux/Manjaro (pacman)

#### Features
- ✅ Automatically detects missing build dependencies
- ✅ Installs required packages using distribution-specific package manager
- ✅ Uses sudo when not running as root
- ✅ Checks for GCC, G++, CMake, Git, curl, wget, libnuma-dev, etc.
- ✅ Dry-run support for dependency installation preview
- ✅ Graceful error handling for unsupported distributions

#### Dependencies Installed
```bash
# Ubuntu/Debian
build-essential, ccache, git, curl, wget, ca-certificates,
gcc, g++, libtcmalloc-minimal4, libnuma-dev, jq, lsof,
numactl, xz-utils, cmake, ninja-build

# Fedora/RHEL/CentOS
@development-tools, ccache, git, curl, wget, ca-certificates,
gcc, gcc-c++, gperftools-libs, numactl-devel, jq, lsof,
numactl, xz, cmake, ninja-build

# openSUSE/SLES
patterns-devel-base-devel_basis, ccache, git, curl, wget,
ca-certificates, gcc, gcc-c++, gperftools, libnuma-devel,
jq, lsof, numactl, xz, cmake, ninja

# Arch/Manjaro
base-devel, ccache, git, curl, wget, ca-certificates,
gcc, gperftools, numactl, jq, lsof, xz, cmake, ninja
```

#### Usage Examples
```bash
# Dependencies installed automatically
./build_wheels.sh --variant=vllm-cpu

# Preview dependency installation
./build_wheels.sh --variant=vllm-cpu --dry-run

# Run as regular user (uses sudo)
./build_wheels.sh --variant=vllm-cpu

# Run as root (no sudo needed)
sudo ./build_wheels.sh --variant=vllm-cpu
```

### Changed
- Version bumped from 2.0.0 to 2.2.0
- Dependency checking now happens before build starts
- Removed manual jq check (handled by dependency installer)

### Benefits
- ✅ No manual dependency installation needed
- ✅ Works across multiple Linux distributions
- ✅ Single command to build from fresh system
- ✅ Better error messages for missing dependencies

---

## [2.1.0] - 2025-11-21

### Added - test_and_publish.sh

#### Multi-Wheel GitHub Releases
- **NEW**: GitHub release support for multi-wheel mode (`--variant=all`)
- **NEW**: `create_all_github_releases()` function to create releases for all wheels
- **NEW**: Each wheel gets its own GitHub release with proper tagging
- **NEW**: Automatic variant name extraction from package names
- **NEW**: Release creation progress tracking with success counters

#### Features
- ✅ Creates individual GitHub releases for each wheel when using `--variant=all`
- ✅ Uses tag format: `v{version}-{variant}` (e.g., `v0.6.3-cpu-avx512`)
- ✅ Attaches appropriate wheel file to each release
- ✅ Skips release creation if release already exists
- ✅ Supports `--skip-github` flag to skip all releases
- ✅ Non-fatal failures (continues if some releases fail)
- ✅ Dry-run support to preview release creation

#### Usage Examples
```bash
# Build and publish all variants with GitHub releases
./test_and_publish.sh --variant=all

# Create releases for existing wheels
./test_and_publish.sh --variant=all --skip-build

# Skip GitHub releases for all wheels
./test_and_publish.sh --variant=all --skip-github

# Preview GitHub release creation
./test_and_publish.sh --variant=all --skip-build --dry-run
```

### Changed
- Version bumped from 2.0.0 to 2.1.0
- Multi-wheel mode documentation updated
- Phase 4 (GitHub Release) now processes all wheels in multi-wheel mode
- Removed previous limitation that skipped GitHub releases in multi-wheel mode

### Fixed
- Multi-wheel mode detection: Now only triggered by `--variant=all` (not `--skip-build`)
- Single-wheel mode with `--skip-build` now works correctly

---

## [2.0.0] - 2025-11-21

### Added - test_and_publish.sh

#### Multi-Wheel Support
- **NEW**: Support for processing multiple wheels in a single run
- **NEW**: `--variant=all` option to build and publish all variants at once
- **NEW**: Automatic multi-wheel detection when `--skip-build` is used
- **NEW**: Batch validation with `validate_all_wheels()` function
- **NEW**: Parallel package testing with `test_all_installations()` function
- **NEW**: Array support for tracking multiple wheels:
  - `WHEEL_PATHS[]` array
  - `PACKAGE_NAMES[]` array
  - `DETECTED_VERSIONS[]` array

#### Functions
- `find_all_wheels()`: Finds all wheels in dist/ directory
- `validate_all_wheels()`: Validates all wheels with twine check
- `test_all_installations()`: Tests installation of all packages from TestPyPI

#### Features
- ✅ Processes 5 variants in one command instead of 5 separate runs
- ✅ Creates separate test environments for each package
- ✅ Skips GitHub releases in multi-wheel mode (create manually)
- ✅ Maintains backward compatibility with single-wheel workflow
- ✅ Smart mode detection (auto-enables multi-wheel when appropriate)

#### Usage Examples
```bash
# Build and publish all 5 variants
./test_and_publish.sh --variant=all

# Use existing wheels
./test_and_publish.sh --skip-build

# Dry-run multi-wheel
./test_and_publish.sh --skip-build --dry-run
```

### Changed
- Version bumped from 1.0.0 to 2.0.0
- Help text updated to mention multi-wheel support
- Main workflow updated to support both single and multi-wheel modes

### Maintained
- ✅ Single-wheel workflow unchanged (backward compatible)
- ✅ All original features preserved
- ✅ Same command-line interface

---

## [2.0.0] - 2025-11-21

### Added - build_wheels.sh

#### Dry-Run Support
- **NEW**: `--dry-run` flag to preview builds without execution
- **NEW**: `run_cmd()` helper function for dry-run mode
- **NEW**: Dry-run banner displayed when enabled
- **NEW**: Shows all operations with [DRY RUN] prefix

#### PyTorch CPU Configuration
- **NEW**: Automatic PyTorch CPU-only installation during build
- **NEW**: Installation instructions added to wheel metadata
- **NEW**: Support for torchvision and torchaudio (required for vision/audio models)

#### Functions
- `run_cmd()`: Executes commands or shows dry-run output

#### Features
- ✅ Preview build operations without executing
- ✅ Shows environment variables in dry-run mode
- ✅ Validates build configuration before starting
- ✅ Reduces installation size by 2.3GB using CPU-only PyTorch

#### Usage Examples
```bash
# Dry-run single variant
./build_wheels.sh --variant=vllm-cpu-avx512vnni --max-jobs=6 --dry-run

# Dry-run all variants
./build_wheels.sh --variant=all --dry-run
```

### Changed
- Version bumped from 1.0.0 to 2.0.0
- Help text updated with --dry-run option
- PyTorch installation now uses CPU-only index
- Build includes torchvision (+7MB) and torchaudio (+3MB)

---

## [2.0.0] - 2025-11-21

### Script Consolidation

#### Consolidated Scripts
- `build_wheels_enhanced.sh` → `build_wheels.sh` (v2.0.0)
- `publish_to_pypi_enhanced.sh` → `publish_to_pypi.sh` (v2.0.0)

#### Backups Created
- `build_wheels.sh.backup` (original v1.0)
- `publish_to_pypi.sh.backup` (original v1.0)

#### Active Scripts (3)
- `build_wheels.sh` v2.0.0 (enhanced)
- `publish_to_pypi.sh` v2.0.0 (enhanced)
- `test_and_publish.sh` v2.0.0 (enhanced)

---

## Documentation Added

### [2.0.0] - 2025-11-21

#### New Documentation Files
1. **CONSOLIDATION_NOTES.md**
   - Script consolidation process
   - Verification steps
   - Rollback procedures

2. **PYTORCH_CPU_DEPENDENCY.md** (400+ lines)
   - PyTorch CPU-only installation guide
   - Size comparisons (210MB vs 2.5GB)
   - Troubleshooting
   - Docker/CI/CD examples

3. **PYTORCH_CPU_CHANGES_SUMMARY.md**
   - Summary of PyTorch CPU integration
   - Before/after comparison

4. **TORCHVISION_TORCHAUDIO_REQUIRED.md** (210 lines)
   - Why torchvision/torchaudio are required
   - Models that use them (12+ models)
   - Size impact analysis (+10MB only)

5. **DRY_RUN_FEATURE.md** (300+ lines)
   - Dry-run usage examples
   - Implementation details
   - Benefits and use cases

6. **MULTI_WHEEL_SUPPORT.md** (600+ lines)
   - Multi-wheel workflow guide
   - Usage examples
   - Performance comparisons
   - Troubleshooting

7. **SESSION_SUMMARY.md**
   - Comprehensive summary of all changes
   - Statistics and metrics

8. **CHANGELOG.md** (this file)
   - Version history
   - All changes documented

---

## Comparison

### Before (v1.0.0)
```bash
# Single-wheel only
./test_and_publish.sh --variant=vllm-cpu
./test_and_publish.sh --variant=vllm-cpu-avx512
./test_and_publish.sh --variant=vllm-cpu-avx512vnni
./test_and_publish.sh --variant=vllm-cpu-avx512bf16
./test_and_publish.sh --variant=vllm-cpu-amxbf16

# 5 separate commands
# 5 separate TestPyPI publishes
# 5 separate production publishes
# 5 confirmation prompts
```

### After (v2.0.0 - v2.1.0)
```bash
# Multi-wheel support with GitHub releases
./build_wheels.sh --variant=all
./test_and_publish.sh --skip-build

# 1 command for all 5 variants
# 1 TestPyPI publish (all wheels)
# 1 production publish (all wheels)
# 5 GitHub releases (automatic)
# 1 confirmation prompt
```

**Time Saved**: 80% reduction in commands
**GitHub Releases**: Automatic for all variants

---

## Statistics

### Code Changes
- **Files Modified**: 2 (build_wheels.sh, test_and_publish.sh)
- **Lines Added**: ~400 lines
- **New Functions**: 4
- **New Variables**: 4 arrays

### Documentation
- **Files Created**: 8 documents
- **Total Lines**: 2,000+ lines of documentation
- **Coverage**: Complete coverage of all features

### Features
- **Multi-wheel support**: ✅ Implemented
- **Dry-run mode**: ✅ Implemented
- **PyTorch CPU**: ✅ Configured
- **Dependencies**: ✅ Verified (torchvision/torchaudio)

---

## Breaking Changes

### None! 🎉

All changes are **backward compatible**. Single-wheel workflows continue to work exactly as before.

---

## Migration Guide

### From v1.0.0 to v2.0.0

#### No Changes Required for Single-Wheel Users
```bash
# This still works exactly the same
./test_and_publish.sh --variant=vllm-cpu-avx512vnni
```

#### New Multi-Wheel Option Available
```bash
# NEW: Process all variants at once
./test_and_publish.sh --variant=all
```

#### New Dry-Run Option
```bash
# NEW: Preview build operations
./build_wheels.sh --variant=vllm-cpu --dry-run
```

---

## Known Issues

### None

All features tested and working correctly.

---

## Future Enhancements (Planned)

### Potential v3.0.0 Features
1. **Parallel builds**: Build multiple variants simultaneously
2. **Caching**: Cache git clones and dependencies
3. **Progress bars**: Visual progress for long operations
4. **JSON output**: Machine-readable output format
5. **Email notifications**: Send completion notifications
6. **Artifact storage**: Upload wheels to cloud storage
7. **Docker support**: Build in containerized environments
8. **Auto-versioning**: Automatic version bumping
9. **Changelog generation**: Auto-generate release notes
10. **Rollback**: Automatic rollback on failures

---

## Contributors

- Claude (Anthropic) - Initial implementation
- Human collaborator - Requirements and testing

---

## License

Same as vLLM project (Apache 2.0)

---

## Links

- **Project**: vLLM CPU Wheel Builder
- **Version**: 2.0.0
- **Date**: 2025-11-21
- **Documentation**: See all *.md files in repository

---

**Last Updated**: 2025-11-21
**Current Version**: 2.2.0 (build_wheels.sh), 2.1.0 (test_and_publish.sh)
**Status**: ✅ Stable
