# Build-Verify-Publish Workflow

## Overview

The `test_and_publish.sh` script implements a **safe, automated workflow** for publishing vLLM CPU wheels to PyPI. It ensures quality through wheel verification before publishing directly to production PyPI.

**Version**: 3.0.0

## Workflow Phases

### Phase 0: Pre-flight Checks
1. Verify all required tools are installed
2. Check if packages already exist on PyPI
3. Detect existing local wheels
4. Determine what needs to be built vs published

### Phase 1: Build and Validate
1. Build wheel for specified variant (if not already built)
2. Locate the built wheel file
3. **Detect vLLM version dynamically** (from wheel filename, git repo, or installed package)
4. Validate with `twine check`

### Wheel Verification
1. Verify ZIP file integrity
2. Check wheel filename format
3. Validate `.dist-info` directory structure
4. Check for required files (METADATA, WHEEL, RECORD)
5. Verify vllm module is present
6. Run `twine check` for package validation
7. **If verification fails, rebuild and re-verify** (max 2 attempts)

### Phase 2: Production Publish
1. Only proceeds if wheel verification passes
2. Publishes directly to production PyPI
3. Uses `--skip-existing` to handle already-published versions

### Phase 3: GitHub Release
1. Only proceeds if PyPI publish succeeds
2. **Uses dynamically detected version for tag** (e.g., `v0.6.3-vllm-cpu`)
3. Creates GitHub release with tag
4. Attaches wheel file to release

## Quick Start

### Basic Usage (Recommended)

```bash
# Build, verify, and publish a single variant
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0

# The script will:
# - Build the wheel (~30-60 min)
# - Verify wheel integrity (ZIP, structure, metadata)
# - Auto-rebuild if verification fails
# - Publish to production PyPI
# - Create GitHub release
```

### Using Existing Wheel

```bash
# If you already built a wheel
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-build
```

### Dry Run (Preview)

```bash
# See what would happen without making changes
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --dry-run
```

## Command Options

```bash
./test_and_publish.sh [OPTIONS]

Options:
  --variant=NAME           Variant to build
                           Values: noavx512, avx512, avx512vnni, avx512bf16, amxbf16, all
                           Default: noavx512 (maps to vllm-cpu package)

  --vllm-versions=VERSION  vLLM version(s) to build
                           Accepts: single (0.11.0) or multiple (0.10.0,0.10.1,0.11.0)
                           Required

  --python-versions=3.X    Python version(s) to build
                           Accepts: single (3.12), multiple (3.10,3.11,3.12), or range (3.10-3.13)
                           Default: 3.13

  --builder=TYPE           Build method
                           Values: native, docker
                           Default: native

  --platform=PLATFORM      Target platform for docker builds
                           Values: auto, linux/amd64, linux/arm64
                           Default: auto

  --dist-dir=DIR           Output directory for wheels
                           Default: dist

  --max-jobs=N             Parallel build jobs
                           Default: CPU count (nproc)

  --skip-build             Skip building, use existing wheels in --dist-dir
                           Default: disabled (builds wheels)

  --skip-github            Skip GitHub release creation
                           Default: disabled (creates GitHub releases)

  --update-readme          Update README inside existing wheels (no rebuild)
                           Extracts wheel, replaces README, repackages
                           Does NOT upload to PyPI - only updates local wheels

  --version-suffix=SUFFIX  Add version suffix for re-uploading deleted wheels
                           PyPI has immutable filename policy - once used, cannot re-upload
                           Values: .post1, .post2, .dev1, .dev2, etc. (PEP 440 compliant)
                           Example: --version-suffix=.post1 turns 0.11.0 into 0.11.0.post1

  --dry-run                Show what would be done without doing it
                           Default: disabled

  --help                   Show help message
```

## Examples

### Example 1: Build and Publish Single Variant

```bash
# Build, verify, and publish vllm-cpu
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0
```

**Expected Output:**
```
╔════════════════════════════════════════════════════════════╗
║     vLLM CPU Build-Verify-Publish Pipeline v3.0.0          ║
╚════════════════════════════════════════════════════════════╝

[INFO] Starting build-verify-publish workflow
[INFO] Variant: vllm-cpu
[INFO] Python: 3.13

=== Phase 0: Pre-flight Checks ===
[INFO] Check 1/1: vllm-cpu v0.11.0 (Python 3.13)
[INFO] Checking if vllm-cpu v0.11.0 exists on pypi.org...

=== Phase 1: Build and Validate (vLLM 0.11.0) ===
[INFO] Building wheels for vLLM 0.11.0...
... (30-60 minutes) ...
[SUCCESS] Wheel built successfully
[INFO] Found 1 wheel(s) for vllm-cpu @ vLLM 0.11.0

=== Wheel Verification (vLLM 0.11.0) ===
[SUCCESS] Wheel verification passed for vllm-cpu @ vLLM 0.11.0

=== Phase 2: Production Publish (vLLM 0.11.0) ===
[SUCCESS] Verification passed for vLLM 0.11.0! Publishing to PyPI...
[SUCCESS] Published to production PyPI

=== Phase 3: GitHub Release (vLLM 0.11.0) ===
[INFO] Creating release: v0.11.0-cpu
[SUCCESS] GitHub release created: v0.11.0-cpu

[SUCCESS] Complete workflow finished successfully!
```

### Example 2: Build Multiple Versions

```bash
# Build and publish multiple vLLM versions
./test_and_publish.sh \
  --variant=vllm-cpu-avx512bf16 \
  --vllm-versions=0.11.0,0.11.1,0.11.2 \
  --python-versions=3.10-3.13
```

### Example 3: Build All Variants

```bash
# Build and publish all 5 CPU variants
./test_and_publish.sh \
  --variant=all \
  --vllm-versions=0.11.0
```

### Example 4: Use Existing Wheels

```bash
# Already built wheels, just verify and publish
./test_and_publish.sh \
  --variant=vllm-cpu \
  --vllm-versions=0.11.0 \
  --skip-build
```

### Example 5: Dry Run Preview

```bash
# See what would happen without making changes
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --dry-run

# Output shows all steps without executing:
# [DRY RUN] Would run: ./build_wheels.sh --variant=vllm-cpu
# [DRY RUN] Would verify wheel integrity
# [DRY RUN] Would upload: vllm_cpu-0.11.0-*.whl
# ...
```

### Example 6: Update README Only

```bash
# Update README in existing wheels without rebuilding
./test_and_publish.sh --update-readme --variant=all --vllm-versions=0.11.0

# This will:
# - Find existing wheels in dist/
# - Update the README.md inside each wheel
# - NOT upload to PyPI
```

## Prerequisites

### Required Tools

```bash
# Check if you have required tools
command -v curl || echo "Need curl"
command -v git || echo "Need git"
command -v jq || echo "Need jq"
command -v zip || echo "Need zip"
command -v unzip || echo "Need unzip"
command -v uv || echo "Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
command -v twine || echo "Install: pip install twine"
command -v gh || echo "Install GitHub CLI (optional for releases)"
```

### Environment Setup

```bash
# 1. PyPI API token in environment or .env
cat > .env <<EOF
PYPI_API_TOKEN=pypi-...your-production-token...
EOF

# 2. Secure .env permissions
chmod 600 .env

# 3. Verify
ls -l .env  # Should show: -rw-------
```

### GitHub CLI Setup (Optional)

```bash
# Install GitHub CLI
# See: https://cli.github.com/

# Authenticate
gh auth login

# Verify
gh auth status
```

## Safety Features

### Wheel Verification

The script performs comprehensive wheel verification:

1. **ZIP Integrity**: Verifies the wheel is a valid ZIP file
2. **Filename Format**: Checks wheel follows PEP 427 naming
3. **Directory Structure**: Validates `.dist-info` directory exists
4. **Required Files**: Checks for METADATA, WHEEL, RECORD
5. **Module Presence**: Verifies vllm module is included
6. **Twine Check**: Runs `twine check` for PyPI compatibility

### Rebuild-on-Failure

If wheel verification fails:
1. Failed wheels are automatically removed
2. Rebuild is triggered immediately
3. Verification is retried (max 2 attempts)
4. Process fails after 2 unsuccessful attempts

### Duplicate Prevention

The script automatically prevents re-publishing:

**PyPI Version Check**:
- Queries PyPI JSON API before publishing
- Uses `--skip-existing` flag with twine
- Prevents "file already exists" errors

**GitHub Release Check**:
- Uses `gh release view` to check for existing release
- Skips creation if tag already exists
- Prevents duplicate release errors

## Parallel Verification

Wheels are verified in parallel for efficiency:
- Up to 8 concurrent verification jobs
- Results collected and reported together
- Fails fast if any wheel verification fails

## Workflow Scenarios

### Scenario 1: Full Release (Recommended)

**Goal**: Release production-ready package

```bash
# Build, verify, and publish
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0

# Script will:
#    - Build wheel
#    - Verify wheel integrity
#    - Rebuild if verification fails
#    - Publish to production PyPI
#    - Create GitHub release
```

### Scenario 2: Build All Variants

**Goal**: Build and publish all 5 CPU variants

```bash
# Build all variants for one version
./test_and_publish.sh --variant=all --vllm-versions=0.11.0

# Build all variants for multiple versions
./test_and_publish.sh --variant=all --vllm-versions=0.11.0,0.11.1,0.11.2
```

### Scenario 3: Re-run After Failure

**Goal**: Resume workflow after fixing an issue

```bash
# First run failed
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0
# ... fails

# Fix the issue, then re-run with existing wheel
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-build
```

### Scenario 4: Skip GitHub Release

**Goal**: Publish to PyPI only, no GitHub release

```bash
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-github
```

## Troubleshooting

### Wheel Verification Fails

**Problem**: Verification reports errors

```bash
# Check wheel manually
unzip -t dist/vllm_cpu-0.11.0-*.whl
twine check dist/vllm_cpu-0.11.0-*.whl

# Examine wheel contents
unzip -l dist/vllm_cpu-0.11.0-*.whl | head -50
```

**Common causes**:
- Corrupted wheel file (rebuild)
- Missing metadata files (check build process)
- Invalid wheel structure (check build script)

### Version Already Exists on PyPI

**Problem**: Trying to publish version that already exists

```bash
# Script automatically detects and skips
[WARNING] Version 0.11.0 already exists on pypi.org
[INFO] Skipping - already published
```

**Solution**: This is handled automatically with `--skip-existing`

### Filename Was Previously Used (Deleted Wheel)

**Problem**: PyPI rejects upload with "filename was previously used"

```bash
ERROR HTTPError: 400 Bad Request from https://upload.pypi.org/legacy/
This filename was previously used by a file that has since been deleted.
```

**Cause**: PyPI has an immutable filename policy. Once a filename is used (even if deleted), it cannot be re-uploaded.

**Solution**: Use `--version-suffix` to create a new version with a PEP 440 compliant suffix:

```bash
# Original wheel was 0.10.0, re-upload as 0.10.0.post1
./test_and_publish.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --version-suffix=.post1

# If .post1 was also deleted, increment: .post2, .post3, etc.
./test_and_publish.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --version-suffix=.post2
```

**Note**: Users install post releases with: `pip install vllm-cpu-avx512==0.10.0.post1`

**Valid suffixes**: Only `.postN` and `.devN` are PEP 440 compliant for PyPI uploads.

### GitHub Release Fails

**Problem**: GitHub CLI not authenticated

```bash
# Check auth status
gh auth status

# Re-authenticate
gh auth login

# Try again
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-build
```

### Build Takes Too Long

**Problem**: Build phase is slow

**Solutions**:
1. Use Docker builder for reproducible builds
2. Limit parallel jobs if memory constrained: `--max-jobs=2`
3. Build one variant at a time

## Time Estimates

| Phase | Time | Notes |
|-------|------|-------|
| Pre-flight checks | <1 min | API queries |
| Build | 30-60 min | Per variant |
| Verification | <1 min | Parallel |
| Production publish | 1-2 min | Upload time |
| GitHub release | <1 min | If gh installed |
| **Total** | **35-65 min** | Per variant |

## Security Notes

### Token Safety

- Tokens are read from `.env` with 600 permissions
- Not exposed in logs or process lists
- Only used for PyPI operations

### Verification Environment

- Wheel verification is file-based (no network)
- No external dependencies during verification
- Safe to run on untrusted wheels

## Related Documentation

- **Build Guide**: See `BUILD_ALL_VARIANTS.md`
- **Publishing Guide**: See `PYPI_PUBLISHING_GUIDE.md`
- **Main Docs**: See `CLAUDE.md`
- **Deployment**: See `DEPLOYMENT_CHECKLIST.md`

## Support

### For Issues

- Check troubleshooting section above
- Verify all prerequisites are installed
- Check `.env` permissions: `ls -l .env` (should be `-rw-------`)

### For Questions

- Script help: `./test_and_publish.sh --help`
- Dry run: `./test_and_publish.sh --dry-run`
- Documentation: This file

---

**Version**: 3.0.0
**Last Updated**: 2025-11-28
**Status**: Ready for Production
