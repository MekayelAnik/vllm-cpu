# Skip Logic Summary

## Overview

The `test_and_publish.sh` script intelligently skips steps that are already completed, preventing duplicate uploads and errors while still ensuring quality through testing.

## Skip Logic Flow

### Phase 1: Build and Validate
```
Build wheel (unless --skip-build)
  ↓
Find wheel and detect version
  ↓
Validate with twine
```
**Skip conditions**: None (always required)

### Phase 2: Test PyPI Verification

#### Step 2.1: Publish to Test PyPI
```
Check if version exists on Test PyPI
  ↓
  ├─→ EXISTS? ──→ Skip publish, use existing package
  └─→ DOESN'T EXIST? ──→ Publish to Test PyPI
```

**Skip conditions**:
- ✅ Version already exists on Test PyPI
- ✅ `--skip-test-pypi` flag provided

**Important**: Even if we skip publishing, we still test the existing package!

#### Step 2.2: Test Installation (Always Runs)
```
Install from Test PyPI (existing or just-published)
  ↓
Verify import vllm
  ↓
Check vllm.__version__
  ↓
Verify version consistency
```

**Skip conditions**:
- ✅ `--skip-test-pypi` flag provided (skips entire phase)

**Key Point**: This step runs even if we skipped publishing in Step 2.1, ensuring the existing Test PyPI package works correctly.

### Phase 3: Production PyPI Publish
```
Check if version exists on production PyPI
  ↓
  ├─→ EXISTS? ──→ Skip publish
  └─→ DOESN'T EXIST? ──→ Ask confirmation → Publish
```

**Skip conditions**:
- ✅ Version already exists on production PyPI
- ✅ Test PyPI tests failed
- ✅ User declines confirmation prompt

### Phase 4: GitHub Release
```
Check if release tag exists
  ↓
  ├─→ EXISTS? ──→ Skip release creation
  └─→ DOESN'T EXIST? ──→ Create release
```

**Skip conditions**:
- ✅ Release tag already exists
- ✅ `--skip-github` flag provided
- ✅ GitHub CLI not installed
- ✅ Not in a git repository
- ✅ Version not detected
- ✅ Production PyPI publish failed

## Detailed Scenarios

### Scenario A: First Run (Nothing Exists)

```bash
./test_and_publish.sh --variant=vllm-cpu

# Flow:
✓ Build wheel
✓ Detect version: 0.6.3
✓ Validate wheel
✓ Check Test PyPI: version doesn't exist
✓ Publish to Test PyPI
✓ Install from Test PyPI
✓ Verify version
✓ Check production PyPI: version doesn't exist
✓ Publish to production PyPI
✓ Check GitHub: release doesn't exist
✓ Create GitHub release

# Result: Everything published
```

### Scenario B: Test PyPI Exists, Others Don't

```bash
./test_and_publish.sh --variant=vllm-cpu --skip-build

# Flow:
✓ Use existing wheel
✓ Detect version: 0.6.3
✓ Validate wheel
✓ Check Test PyPI: version EXISTS ← Skip publish
⏭️ Skip Test PyPI publish
✓ Install from Test PyPI (existing package) ← Still tests!
✓ Verify version works
✓ Check production PyPI: version doesn't exist
✓ Publish to production PyPI
✓ Check GitHub: release doesn't exist
✓ Create GitHub release

# Result: Tested existing Test PyPI package, published to production and GitHub
```

### Scenario C: All Exist (Re-run)

```bash
./test_and_publish.sh --variant=vllm-cpu --skip-build

# Flow:
✓ Use existing wheel
✓ Detect version: 0.6.3
✓ Validate wheel
✓ Check Test PyPI: version EXISTS ← Skip publish
⏭️ Skip Test PyPI publish
✓ Install from Test PyPI (existing package) ← Still tests!
✓ Verify version works
✓ Check production PyPI: version EXISTS ← Skip publish
⏭️ Skip production PyPI publish
✓ Check GitHub: release EXISTS ← Skip creation
⏭️ Skip GitHub release

# Result: Only tested existing Test PyPI package, everything else skipped
```

### Scenario D: Test PyPI Package Broken

```bash
./test_and_publish.sh --variant=vllm-cpu --skip-build

# Flow:
✓ Use existing wheel
✓ Detect version: 0.6.3
✓ Validate wheel
✓ Check Test PyPI: version EXISTS
⏭️ Skip Test PyPI publish
✓ Install from Test PyPI (existing package)
✗ FAIL: Can't import vllm

# Result: Stops here, won't publish to production
# This is the safety mechanism!
```

## Implementation Details

### Test PyPI Existence Check

**Function**: `check_pypi_version_exists()`

**Location**: test_and_publish.sh:240-270

```bash
check_pypi_version_exists() {
    local package_name="$1"
    local version="$2"
    local pypi_url="$3"  # "https://pypi.org" or "https://test.pypi.org"

    # Query PyPI JSON API
    local response
    response=$(curl -s "$pypi_url/pypi/$package_name/json" 2>/dev/null)

    # Check if specific version exists
    if echo "$response" | grep -q "\"$version\""; then
        return 0  # Version exists
    fi

    return 1  # Version doesn't exist
}
```

**How it works**:
1. Queries PyPI JSON API endpoint
2. Searches for version string in response
3. Returns 0 (exists) or 1 (doesn't exist)

**Example API response**:
```json
{
  "info": {
    "name": "vllm-cpu",
    "version": "0.6.3"
  },
  "releases": {
    "0.6.2": [...],
    "0.6.3": [...]
  }
}
```

### Test Installation Logic

**Function**: `test_installation()`

**Location**: test_and_publish.sh:307-393

**Key code**:
```bash
# This runs EVEN IF we skipped publishing
log_info "Testing installation from Test PyPI..."
log_info "Installing $PACKAGE_NAME from Test PyPI..."

pip install --index-url https://test.pypi.org/simple/ \
     --extra-index-url https://pypi.org/simple/ \
     "$PACKAGE_NAME"

# Verify it works
python -c "import vllm"
python -c "import vllm; print(vllm.__version__)"
```

**Why this matters**:
- Tests existing packages before proceeding to production
- Catches corrupted/broken uploads
- Verifies version consistency
- Prevents publishing broken packages to production

### Production PyPI Existence Check

**Function**: `publish_to_production_pypi()`

**Location**: test_and_publish.sh:395-427

**Key code**:
```bash
# Check if version already exists on production PyPI
if check_pypi_version_exists "$PACKAGE_NAME" "$DETECTED_VERSION" "https://pypi.org"; then
    log_warning "Skipping production PyPI publish - version already exists"
    return 0
fi
```

**Why this matters**:
- Prevents "file already exists" errors from PyPI
- PyPI doesn't allow overwriting published versions
- Saves time and API quota

### GitHub Release Existence Check

**Function**: `check_github_release_exists()`

**Location**: test_and_publish.sh:429-453

**Key code**:
```bash
check_github_release_exists() {
    local tag="$1"

    # Check if release exists
    if gh release view "$tag" &>/dev/null; then
        return 0  # Release exists
    fi

    return 1  # Release doesn't exist
}
```

**How it works**:
1. Uses GitHub CLI `gh release view`
2. Checks if tag exists
3. Returns 0 (exists) or 1 (doesn't exist)

## Benefits of Skip Logic

### 1. Idempotency

Run the script multiple times safely:
```bash
# First run
./test_and_publish.sh --variant=vllm-cpu
# ✓ Everything published

# Second run (accidental)
./test_and_publish.sh --variant=vllm-cpu
# ⏭️ Everything skipped (already exists)
# No errors!
```

### 2. Resume After Failure

Continue from where you left off:
```bash
# Run fails at production PyPI
./test_and_publish.sh --variant=vllm-cpu
# ✓ Built wheel
# ✓ Published to Test PyPI
# ✓ Tested installation
# ✗ Failed at production PyPI

# Fix issue, re-run
./test_and_publish.sh --variant=vllm-cpu --skip-build
# ⏭️ Skip Test PyPI (exists)
# ✓ Test existing package
# ✓ Publish to production (retry)
# ✓ Create GitHub release
```

### 3. Quality Assurance

Always test existing packages:
```bash
# Test PyPI package exists, but is it good?
./test_and_publish.sh --variant=vllm-cpu --skip-build
# ⏭️ Skip Test PyPI publish
# ✓ Test existing package ← This always runs!
# ✗ FAIL if package broken
# → Won't proceed to production
```

### 4. Safe Re-runs

Developers can re-run without worry:
```bash
# Not sure if published?
./test_and_publish.sh --variant=vllm-cpu --skip-build
# Script checks everything and skips what's done
```

## Example Output

### When Everything is Skipped

```bash
$ ./test_and_publish.sh --variant=vllm-cpu --skip-build

2025-11-21 10:00:00 [12345] [INFO] Starting test-then-publish workflow

=== Phase 1: Build and Validate ===
[INFO] Skipping build (--skip-build specified)
[INFO] Found wheel: dist/vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
[INFO] Detected version from wheel: 0.6.3
[SUCCESS] Wheel validation passed

=== Phase 2: Test PyPI Verification ===
[INFO] Checking if vllm-cpu v0.6.3 exists on test.pypi.org...
[WARNING] Version 0.6.3 already exists on test.pypi.org
[WARNING] Skipping Test PyPI publish - version already exists
[INFO] You can test installation from existing package
[INFO] Testing installation from Test PyPI...
[INFO] Installing vllm-cpu from Test PyPI...
[SUCCESS] Package installed from Test PyPI
[SUCCESS] vLLM import successful
[SUCCESS] vLLM version: 0.6.3
[SUCCESS] Test PyPI installation verification complete

=== Phase 3: Production Publish ===
[INFO] Checking if vllm-cpu v0.6.3 exists on pypi.org...
[WARNING] Version 0.6.3 already exists on pypi.org
[WARNING] Skipping production PyPI publish - version already exists
[INFO] Version 0.6.3 is already published on PyPI

=== Phase 4: GitHub Release ===
[INFO] Checking if GitHub release v0.6.3-vllm-cpu exists...
[WARNING] GitHub release v0.6.3-vllm-cpu already exists
[WARNING] Skipping GitHub release creation - release already exists
[INFO] Existing release: v0.6.3-vllm-cpu

[SUCCESS] Complete workflow finished successfully!
[INFO] Package: vllm-cpu
[INFO] Version: 0.6.3
[INFO] Wheel: dist/vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
```

### When Only Test PyPI is Skipped

```bash
$ ./test_and_publish.sh --variant=vllm-cpu --skip-build

=== Phase 2: Test PyPI Verification ===
[WARNING] Skipping Test PyPI publish - version already exists ← Skipped
[INFO] Testing installation from Test PyPI... ← Still tests!
[SUCCESS] vLLM version: 0.6.3

=== Phase 3: Production Publish ===
[INFO] Checking if vllm-cpu v0.6.3 exists on pypi.org...
[INFO] Version 0.6.3 not found on pypi.org ← Doesn't exist
[INFO] Publishing to production PyPI... ← Publishes!
Are you sure you want to continue? (yes/no): yes
[SUCCESS] Published to production PyPI
```

## Testing the Skip Logic

### Test 1: Verify Test PyPI Skip Works

```bash
# First run
./test_and_publish.sh --variant=vllm-cpu --skip-github
# Should publish to Test PyPI

# Second run
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-github
# Should skip Test PyPI but still test installation

# Check logs for:
# [WARNING] Skipping Test PyPI publish - version already exists
# [INFO] Testing installation from Test PyPI...
```

### Test 2: Verify Production PyPI Skip Works

```bash
# Publish to production
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-github

# Try again
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-github

# Check logs for:
# [WARNING] Skipping production PyPI publish - version already exists
```

### Test 3: Verify GitHub Release Skip Works

```bash
# Create release
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-test-pypi

# Try again
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-test-pypi

# Check logs for:
# [WARNING] Skipping GitHub release creation - release already exists
```

### Test 4: Verify Broken Package Detected

```bash
# Upload broken package to Test PyPI
# (manually upload corrupted wheel)

# Try to publish
./test_and_publish.sh --variant=vllm-cpu --skip-build

# Should:
# ⏭️ Skip Test PyPI publish (exists)
# ✓ Try to install from Test PyPI
# ✗ FAIL at import or version check
# → Stop, don't publish to production
```

## Summary

The skip logic ensures:

✅ **No duplicate uploads** - Checks before uploading
✅ **Always tests** - Even skipped packages are tested
✅ **Idempotent** - Safe to re-run multiple times
✅ **Resumable** - Continue after failures
✅ **Quality gates** - Broken packages caught before production
✅ **Clear feedback** - Logs show what's skipped and why

**Key insight**: Skipping upload doesn't mean skipping tests. The script always verifies existing Test PyPI packages work before proceeding to production.

---

**Version**: 1.0.0
**Date**: 2025-11-21
**Status**: ✅ Implemented and Tested
