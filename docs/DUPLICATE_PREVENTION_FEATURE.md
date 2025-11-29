# Duplicate Prevention Feature

## Overview

The `test_and_publish.sh` script now includes intelligent duplicate detection and prevention, automatically checking if versions already exist before attempting to publish. This prevents errors, saves time, and enables safe re-runs.

## What Was Added

### 1. PyPI Version Existence Check

**Function**: `check_pypi_version_exists()`

Queries the PyPI JSON API to check if a specific version of a package already exists.

```bash
check_pypi_version_exists "vllm-cpu" "0.6.3" "https://pypi.org"
# Returns 0 if exists, 1 if doesn't exist
```

**Features**:
- Works for both Test PyPI and production PyPI
- Uses official PyPI JSON API
- Fast and reliable
- No authentication required (read-only)

### 2. GitHub Release Existence Check

**Function**: `check_github_release_exists()`

Uses GitHub CLI to check if a release tag already exists.

```bash
check_github_release_exists "v0.6.3-vllm-cpu"
# Returns 0 if exists, 1 if doesn't exist
```

**Features**:
- Uses `gh release view` command
- Checks for exact tag match
- Requires GitHub CLI installed
- Gracefully handles missing CLI

### 3. Automatic Skip Logic

The script now automatically skips operations when duplicates are detected:

**Test PyPI**:
```bash
if check_pypi_version_exists "$PACKAGE_NAME" "$DETECTED_VERSION" "https://test.pypi.org"; then
    log_warning "Skipping Test PyPI publish - version already exists"
    return 0  # Skip, but continue to test installation
fi
```

**Production PyPI**:
```bash
if check_pypi_version_exists "$PACKAGE_NAME" "$DETECTED_VERSION" "https://pypi.org"; then
    log_warning "Skipping production PyPI publish - version already exists"
    return 0  # Skip completely
fi
```

**GitHub Release**:
```bash
if check_github_release_exists "$tag"; then
    log_warning "Skipping GitHub release creation - release already exists"
    return 0  # Skip completely
fi
```

## How It Works

### Workflow with Duplicate Detection

```
┌─────────────────────────────────────────┐
│ Phase 1: Build and Validate             │
├─────────────────────────────────────────┤
│ • Build wheel                            │
│ • Detect version                         │
│ • Validate with twine                    │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ Phase 2: Test PyPI Verification         │
├─────────────────────────────────────────┤
│ Check if version exists on Test PyPI    │
│    ├─ EXISTS? → Skip publish            │
│    └─ NEW? → Publish to Test PyPI       │
│                  ↓                       │
│ Install from Test PyPI (always!)        │
│ Verify import and version                │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ Phase 3: Production PyPI Publish        │
├─────────────────────────────────────────┤
│ Check if version exists on PyPI          │
│    ├─ EXISTS? → Skip publish             │
│    └─ NEW? → Ask confirmation → Publish  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ Phase 4: GitHub Release                  │
├─────────────────────────────────────────┤
│ Check if release exists                  │
│    ├─ EXISTS? → Skip creation            │
│    └─ NEW? → Create release              │
└─────────────────────────────────────────┘
```

### Key Behavior: Test PyPI

**Important**: Even when Test PyPI upload is skipped, installation testing still occurs!

```bash
# Version exists on Test PyPI
[WARNING] Skipping Test PyPI publish - version already exists

# But testing continues!
[INFO] Testing installation from Test PyPI...
[INFO] Installing vllm-cpu from Test PyPI...
[SUCCESS] Package installed from Test PyPI
[SUCCESS] vLLM version: 0.6.3

# This ensures existing packages work before proceeding to production
```

## Benefits

### 1. Prevents Upload Errors

**Before** (without duplicate detection):
```bash
$ ./test_and_publish.sh --variant=vllm-cpu
...
Uploading vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl
ERROR: File already exists. See https://pypi.org/help/#file-name-reuse
```

**After** (with duplicate detection):
```bash
$ ./test_and_publish.sh --variant=vllm-cpu
...
[WARNING] Version 0.6.3 already exists on pypi.org
[WARNING] Skipping production PyPI publish - version already exists
[SUCCESS] Complete workflow finished successfully!
```

### 2. Enables Safe Re-runs

Run the script multiple times without errors:

```bash
# First run
$ ./test_and_publish.sh --variant=vllm-cpu
[SUCCESS] Published to Test PyPI
[SUCCESS] Published to production PyPI
[SUCCESS] GitHub release created

# Second run (accidental)
$ ./test_and_publish.sh --variant=vllm-cpu --skip-build
[WARNING] Skipping Test PyPI publish - version already exists
[WARNING] Skipping production PyPI publish - version already exists
[WARNING] Skipping GitHub release creation - release already exists
[SUCCESS] Complete workflow finished successfully!

# No errors, everything safe!
```

### 3. Supports Resumable Workflows

Continue from where you left off:

```bash
# Run fails at production publish
$ ./test_and_publish.sh --variant=vllm-cpu
[SUCCESS] Published to Test PyPI
[SUCCESS] Tested installation
[ERROR] Production PyPI publish failed

# Fix the issue (e.g., add missing API token)
# Re-run from same point
$ ./test_and_publish.sh --variant=vllm-cpu --skip-build
[WARNING] Skipping Test PyPI publish - version already exists ← Smart skip
[SUCCESS] Tested installation ← Still verifies
[SUCCESS] Published to production PyPI ← Resumes here
[SUCCESS] GitHub release created
```

### 4. Quality Assurance

Always tests existing Test PyPI packages:

```bash
# Test PyPI package exists, script tests it
$ ./test_and_publish.sh --variant=vllm-cpu --skip-build
[WARNING] Skipping Test PyPI publish - version already exists
[INFO] Testing installation from Test PyPI...
[ERROR] Failed to import vllm ← Catches broken packages!

# Won't proceed to production with broken package
```

## Usage Examples

### Example 1: Check Before Publishing

```bash
# Dry run to see what would happen
./test_and_publish.sh --variant=vllm-cpu --dry-run

# Output shows:
[DRY RUN] Would check: https://test.pypi.org/pypi/vllm-cpu/json
[DRY RUN] Would check: https://pypi.org/pypi/vllm-cpu/json
[DRY RUN] Would check: gh release view v0.6.3-vllm-cpu
```

### Example 2: Re-run After Partial Success

```bash
# Initial run partially succeeds
./test_and_publish.sh --variant=vllm-cpu
# ✓ Published to Test PyPI
# ✓ Published to production PyPI
# ✗ GitHub release failed (no gh CLI)

# Install gh CLI
sudo apt install gh
gh auth login

# Re-run to just create release
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-test-pypi
# ⏭️ Skips Test PyPI
# ⏭️ Skips production PyPI (already exists)
# ✓ Creates GitHub release
```

### Example 3: Test Existing Packages

```bash
# Only test, don't publish anything new
./test_and_publish.sh --variant=vllm-cpu --skip-build

# If all versions exist:
# ⏭️ Skips Test PyPI publish
# ✓ Tests existing Test PyPI package
# ⏭️ Skips production PyPI publish
# ⏭️ Skips GitHub release

# Result: Verified existing package works
```

### Example 4: Publish New Variant

```bash
# Published vllm-cpu already, now publish vllm-cpu-avx512
./test_and_publish.sh --variant=vllm-cpu-avx512 --skip-build

# Even though vllm-cpu v0.6.3 exists, vllm-cpu-avx512 v0.6.3 doesn't
# ✓ Publishes vllm-cpu-avx512 to Test PyPI (new package)
# ✓ Tests installation
# ✓ Publishes to production PyPI (new package)
# ✓ Creates GitHub release (new tag)
```

## Technical Implementation

### PyPI JSON API

The script queries PyPI's JSON API endpoint:

```bash
# Endpoint format
https://pypi.org/pypi/{package_name}/json
https://test.pypi.org/pypi/{package_name}/json

# Example
curl -s https://pypi.org/pypi/vllm-cpu/json
```

**Response format**:
```json
{
  "info": {
    "author": "vLLM Team",
    "name": "vllm-cpu",
    "version": "0.6.3",
    "summary": "..."
  },
  "releases": {
    "0.6.2": [
      {
        "filename": "vllm_cpu-0.6.2-cp313-cp313-linux_x86_64.whl",
        "upload_time": "2024-01-15T10:30:00"
      }
    ],
    "0.6.3": [
      {
        "filename": "vllm_cpu-0.6.3-cp313-cp313-linux_x86_64.whl",
        "upload_time": "2024-01-20T14:20:00"
      }
    ]
  }
}
```

The script searches for the version string in the response:
```bash
if echo "$response" | grep -q "\"$version\""; then
    return 0  # Version exists
fi
```

### GitHub CLI Integration

The script uses GitHub CLI's `release view` command:

```bash
# Check if release exists
gh release view v0.6.3-vllm-cpu &>/dev/null

# Returns:
# 0 (success) = release exists
# 1 (error) = release doesn't exist
```

**Error output** (when doesn't exist):
```
release not found
```

The script redirects stderr to `/dev/null` to suppress the error message.

### Error Handling

All checks handle errors gracefully:

```bash
# If PyPI is down
response=$(curl -s "$pypi_url/pypi/$package_name/json" 2>/dev/null)
if [[ -z "$response" ]]; then
    log_info "Package not found, assuming doesn't exist"
    return 1  # Safe default: assume doesn't exist
fi

# If gh not installed
if ! command -v gh &> /dev/null; then
    log_warning "GitHub CLI not found, cannot check existing releases"
    return 1  # Safe default: assume doesn't exist
fi
```

## Testing

### Test 1: Verify Duplicate Detection

```bash
# Publish once
./test_and_publish.sh --variant=vllm-cpu
# Should succeed

# Try again
./test_and_publish.sh --variant=vllm-cpu --skip-build
# Should skip all with warnings

# Verify output contains:
grep "Skipping.*publish.*already exists" <log_file>
```

### Test 2: Verify Test Installation Still Runs

```bash
# With existing Test PyPI package
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-github

# Check logs show:
# [WARNING] Skipping Test PyPI publish - version already exists
# [INFO] Testing installation from Test PyPI...
# [SUCCESS] Package installed from Test PyPI
```

### Test 3: Test API Failures

```bash
# Disconnect network
sudo iptables -A OUTPUT -d pypi.org -j DROP

# Run script
./test_and_publish.sh --variant=vllm-cpu --skip-build

# Should:
# - Fail to check PyPI existence
# - Assume doesn't exist
# - Attempt to publish (which will also fail)
```

### Test 4: Test GitHub CLI Missing

```bash
# Remove gh from PATH
export PATH=$(echo $PATH | sed 's|:/usr/bin/gh||')

# Run script
./test_and_publish.sh --variant=vllm-cpu --skip-build --skip-test-pypi

# Should:
# [WARNING] GitHub CLI (gh) not found. Skipping release creation.
# No error, continues gracefully
```

## Limitations

### 1. API Rate Limits

PyPI JSON API has rate limits:
- Generally high enough for normal use
- Could be issue in automated CI/CD with many runs
- Solution: Add delays between checks or cache results

### 2. Network Dependency

Checks require network access:
- If offline, checks fail
- Default behavior: assume doesn't exist
- Could lead to upload attempts that fail

### 3. No Checksum Verification

Script only checks if version exists, not if file is identical:
- Different files with same version not detected
- PyPI prevents this anyway (rejects duplicate filenames)
- GitHub allows replacing release assets

## Future Enhancements

### Possible improvements:

1. **Checksum Verification**
   ```bash
   # Download existing wheel, compare checksums
   existing_sha256=$(curl -s "$pypi_url/pypi/$package/json" | jq -r ".releases[\"$version\"][0].digests.sha256")
   local_sha256=$(sha256sum "$WHEEL_PATH" | cut -d' ' -f1)
   if [[ "$existing_sha256" == "$local_sha256" ]]; then
       echo "Identical wheel already published"
   fi
   ```

2. **Cache API Responses**
   ```bash
   # Cache JSON responses to reduce API calls
   cache_file="/tmp/pypi-cache-$PACKAGE_NAME.json"
   if [[ -f "$cache_file" ]] && [[ $(find "$cache_file" -mmin -60) ]]; then
       response=$(cat "$cache_file")
   else
       response=$(curl -s "$pypi_url/pypi/$package_name/json")
       echo "$response" > "$cache_file"
   fi
   ```

3. **List All Published Versions**
   ```bash
   # Show user what versions exist
   list_published_versions() {
       curl -s "https://pypi.org/pypi/$package/json" | \
           jq -r '.releases | keys[]' | sort -V
   }
   ```

4. **Force Re-publish Option**
   ```bash
   # Add --force flag to override checks
   if [[ $FORCE_PUBLISH -eq 1 ]]; then
       log_warning "Force publish enabled, skipping existence checks"
   else
       check_pypi_version_exists ...
   fi
   ```

## Summary

The duplicate prevention feature:

✅ **Prevents errors** - No "file already exists" failures
✅ **Enables re-runs** - Safe to run multiple times
✅ **Supports resume** - Continue after failures
✅ **Quality gates** - Always tests existing packages
✅ **User-friendly** - Clear warnings and messages
✅ **Efficient** - Skips unnecessary uploads
✅ **Robust** - Handles edge cases gracefully

**Key design principle**: Skip uploads but never skip testing. Even if a package exists on Test PyPI, we still verify it works before proceeding to production.

---

**Version**: 1.0.0
**Date**: 2025-11-21
**Status**: ✅ Implemented and Tested
