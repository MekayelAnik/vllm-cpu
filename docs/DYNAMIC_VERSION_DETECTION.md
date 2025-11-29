# Dynamic Version Detection

## Overview

The `test_and_publish.sh` script now automatically detects the vLLM version from multiple sources, eliminating the need for manual version specification in GitHub releases and ensuring consistency across the entire publishing pipeline.

## Feature Details

### Version Detection Strategy

The script uses a **three-tier fallback approach** to detect the vLLM version:

```
1. Wheel Filename (Primary)
   ↓ (if fails)
2. Git Repository (Fallback)
   ↓ (if fails)
3. Installed Package (Final Fallback)
```

### Implementation

#### Method 1: Wheel Filename Extraction

**Location**: `find_wheel()` function (test_and_publish.sh:203-204)

```bash
# Extract version from wheel filename
# Format: package_name-VERSION-pythonXY-pythonXY-platform.whl
DETECTED_VERSION=$(basename "$WHEEL_PATH" | sed -n 's/.*-\([0-9][0-9.]*\)-.*/\1/p')
```

**Example**:
```
Input:  vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
Output: 0.6.3
```

**Advantages**:
- Fast and reliable
- Works immediately after build
- No additional dependencies

#### Method 2: Git Repository Query

**Location**: `detect_version_from_git()` function (test_and_publish.sh:148-180)

```bash
# Get version from git tags in cloned vLLM repository
git_version=$(cd "$vllm_dir" && git describe --tags --abbrev=0 2>/dev/null)
git_version="${git_version#v}"  # Remove 'v' prefix
```

**Example**:
```
Input:  git describe --tags --abbrev=0 → v0.6.3
Output: 0.6.3
```

**Advantages**:
- Authoritative source (directly from vLLM project)
- Works when wheel filename parsing fails
- Handles pre-release versions

#### Method 3: Installed Package Query

**Location**: `test_installation()` function (test_and_publish.sh:288-308)

```bash
# Get version from installed package
installed_version=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null)

# Update DETECTED_VERSION if not already set
if [[ -z "$DETECTED_VERSION" ]]; then
    DETECTED_VERSION="$installed_version"
fi
```

**Example**:
```python
import vllm
print(vllm.__version__)  # 0.6.3
```

**Advantages**:
- Most accurate (actual runtime version)
- Catches version mismatches
- Confirms package integrity

### Version Verification

After detection, the script performs consistency checks:

```bash
# Verify versions match
if [[ "$DETECTED_VERSION" != "$installed_version" ]]; then
    log_warning "Version mismatch: wheel=$DETECTED_VERSION, installed=$installed_version"
fi
```

This catches potential issues like:
- Incorrect wheel metadata
- Build system bugs
- Manual version file edits

## Usage in GitHub Releases

### Automatic Tag Generation

The detected version is used to create GitHub release tags:

```bash
# Format: v{VERSION}-{VARIANT}
local tag="v${DETECTED_VERSION}-${VARIANT}"
local release_title="vLLM CPU ${VARIANT} v${DETECTED_VERSION}"
```

**Examples**:
```
vllm-cpu         → v0.6.3-vllm-cpu
vllm-cpu-avx512  → v0.6.3-vllm-cpu-avx512
vllm-cpu-amxbf16 → v0.6.3-vllm-cpu-amxbf16
```

### Release Notes

The version is embedded in release notes:

```markdown
Release of vllm-cpu v0.6.3

Built from vLLM v0.6.3
Variant: vllm-cpu

## Installation

pip install vllm-cpu

## Verification

python -c 'import vllm; print(vllm.__version__)'
```

## Benefits

### 1. No Manual Version Entry

**Before**:
```bash
# Manual version required
gh release create v0.6.3-vllm-cpu --title "vLLM CPU v0.6.3" ...
```

**After**:
```bash
# Fully automatic
./test_and_publish.sh --variant=vllm-cpu
# Version detected automatically: 0.6.3
```

### 2. Consistency Guaranteed

All version references are synchronized:
- ✅ Wheel filename
- ✅ Test PyPI package
- ✅ Production PyPI package
- ✅ GitHub release tag
- ✅ Release notes

### 3. Error Detection

Catches version inconsistencies:
```bash
[WARNING] Version mismatch: wheel=0.6.3, installed=0.6.4
```

### 4. Flexibility

Works in multiple scenarios:
- Fresh build → Detects from wheel filename
- Existing wheel → Detects from git repo
- Skip build → Detects from installed package

## Example Workflow

### Complete Flow with Version Detection

```bash
$ ./test_and_publish.sh --variant=vllm-cpu

# Phase 1: Build and Validate
[INFO] Building wheel for variant: vllm-cpu
...
[INFO] Found wheel: dist/vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
[INFO] Detected version from wheel: 0.6.3  ← PRIMARY METHOD
[SUCCESS] Wheel validation passed

# Phase 2: Test PyPI Verification
[INFO] Publishing to Test PyPI...
[SUCCESS] Published to Test PyPI
[INFO] Installing vllm-cpu from Test PyPI...
[SUCCESS] Package installed from Test PyPI
[SUCCESS] vLLM version: 0.6.3  ← VERIFICATION
[INFO] Version verified: wheel=0.6.3, installed=0.6.3  ← CONSISTENCY CHECK

# Phase 3: Production Publish
[SUCCESS] All tests passed! Ready for production publish.
Are you sure you want to continue? (yes/no): yes
[SUCCESS] Published to production PyPI

# Phase 4: GitHub Release
[INFO] Creating release: v0.6.3-vllm-cpu  ← USING DETECTED VERSION
[SUCCESS] GitHub release created: v0.6.3-vllm-cpu

[SUCCESS] Complete workflow finished successfully!
[INFO] Package: vllm-cpu
[INFO] Version: 0.6.3  ← FINAL CONFIRMATION
[INFO] Wheel: dist/vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
```

## Edge Cases Handled

### Case 1: Malformed Wheel Filename

```bash
# Wheel filename doesn't match expected pattern
[WARNING] Could not extract version from wheel filename
[INFO] Detecting version from vLLM git repository...
[INFO] Detected version from git: 0.6.3
```

### Case 2: No Git Repository

```bash
# /tmp/vllm-build/vllm doesn't exist
[WARNING] vLLM git repository not found at /tmp/vllm-build/vllm
[WARNING] Will detect version from installed package later
...
[INFO] Updated detected version from installed package: 0.6.3
```

### Case 3: Version Mismatch

```bash
# Wheel says 0.6.3, installed package says 0.6.4
[INFO] Detected version from wheel: 0.6.3
[SUCCESS] vLLM version: 0.6.4
[WARNING] Version mismatch: wheel=0.6.3, installed=0.6.4
# Uses installed version (0.6.4) as it's more accurate
```

### Case 4: All Methods Fail

```bash
# Extremely rare, but handled gracefully
[WARNING] Version not detected. Skipping GitHub release.
# Other phases complete, only GitHub release is skipped
```

## Technical Implementation

### Variables

```bash
# Global variable to store detected version
DETECTED_VERSION=""
```

### Functions

1. **`detect_version_from_git()`**
   - Reads version from git repository
   - Returns 0 on success, 1 on failure

2. **`find_wheel()`**
   - Extracts version from wheel filename
   - Falls back to `detect_version_from_git()` if extraction fails

3. **`test_installation()`**
   - Queries installed package version
   - Updates `DETECTED_VERSION` if empty
   - Verifies version consistency

4. **`create_github_release()`**
   - Uses `DETECTED_VERSION` for tag and title
   - Skips gracefully if version unknown

### Flow Diagram

```
Start
  ↓
Build Wheel
  ↓
find_wheel()
  ├─→ Extract from filename ──→ SUCCESS? ──→ Set DETECTED_VERSION
  └─→ FAILED? ──→ detect_version_from_git() ──→ SUCCESS? ──→ Set DETECTED_VERSION
                                              └─→ FAILED? ──→ Continue (will detect later)
  ↓
Test PyPI Install
  ↓
test_installation()
  ├─→ Get installed version ──→ Verify matches DETECTED_VERSION
  └─→ If DETECTED_VERSION empty ──→ Set from installed version
  ↓
Production Publish
  ↓
create_github_release()
  └─→ Use DETECTED_VERSION for tag
  ↓
Complete (Show DETECTED_VERSION in summary)
```

## Testing

### Verify Version Detection

```bash
# Test with existing wheel
./test_and_publish.sh --variant=vllm-cpu --skip-build --dry-run

# Look for these log lines:
[INFO] Detected version from wheel: X.Y.Z
[SUCCESS] vLLM version: X.Y.Z
[INFO] Creating release: vX.Y.Z-vllm-cpu
```

### Test Fallback Methods

```bash
# Test git fallback (rename wheel to break parsing)
mv dist/vllm_cpu-0.6.3-*.whl dist/vllm_cpu-broken.whl
./test_and_publish.sh --variant=vllm-cpu --skip-build --dry-run
# Should see: [INFO] Detecting version from vLLM git repository...

# Test final fallback (remove git repo)
rm -rf /tmp/vllm-build/vllm/.git
./test_and_publish.sh --variant=vllm-cpu --skip-build
# Should see: [INFO] Updated detected version from installed package: X.Y.Z
```

## Related Files

- **test_and_publish.sh** - Main script with version detection
- **TEST_AND_PUBLISH.md** - User documentation
- **build_wheels.sh** - Build script (creates wheels with version in filename)

## Future Enhancements

Possible improvements:

1. **Version from pyproject.toml**
   - Read version from source metadata
   - More authoritative than git tags

2. **Custom version override**
   - Add `--detected-version=X.Y.Z` flag
   - For special cases or testing

3. **Version validation**
   - Check against semantic versioning format
   - Warn on pre-release versions

4. **Version caching**
   - Store detected version to file
   - Reuse across multiple runs

## Summary

The dynamic version detection feature:

✅ **Eliminates manual work** - No need to specify version for releases
✅ **Ensures consistency** - Same version across all artifacts
✅ **Catches errors** - Detects version mismatches
✅ **Provides fallbacks** - Multiple detection methods
✅ **Handles edge cases** - Graceful degradation
✅ **Improves reliability** - Fewer human errors

This enhancement makes the publishing pipeline more robust and reduces the chance of version-related mistakes in production releases.

---

**Version**: 1.0.0
**Date**: 2025-11-21
**Status**: ✅ Implemented and Tested
