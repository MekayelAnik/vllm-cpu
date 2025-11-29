# Quick Reference - Build-Verify-Publish Pipeline

## Most Common Commands

```bash
# Full workflow (build + verify + publish + release)
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0

# Use existing wheel
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-build

# Preview without changes
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --dry-run

# Skip GitHub release
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-github
```

## Build All Variants

```bash
# Build all 5 variants
./build_wheels.sh --variant=all --vllm-versions=0.11.0

# Build and publish all variants
./test_and_publish.sh --variant=all --vllm-versions=0.11.0
```

## Workflow Phases

| Phase | What It Does | Skippable? |
|-------|--------------|------------|
| 0. Pre-flight | Check PyPI status, local wheels | ❌ |
| 1. Build | Builds wheel | `--skip-build` |
| Verification | Verify wheel integrity (ZIP, structure, metadata) | ❌ (automatic rebuild on failure) |
| 2. Production PyPI | Publishes to production PyPI | ❌ (only if verification passes) |
| 3. GitHub Release | Creates release with tag | `--skip-github` |

## What Gets Verified

### Wheel Verification

- ZIP file integrity
- Wheel filename format (PEP 427)
- `.dist-info` directory structure
- Required files: METADATA, WHEEL, RECORD
- vllm module presence
- `twine check` validation

### Before Production Publish

- Version exists on production PyPI? (skip if yes)
- All wheel verifications passed
- Rebuild attempted if verification failed (max 2 times)

### Before GitHub Release

- Release tag exists? (skip if yes)
- Version detected successfully
- GitHub CLI available

## Expected Output

```bash
╔════════════════════════════════════════════════════════════╗
║     vLLM CPU Build-Verify-Publish Pipeline v3.0.0          ║
╚════════════════════════════════════════════════════════════╝

=== Phase 0: Pre-flight Checks ===
[INFO] Check 1/1: vllm-cpu v0.11.0 (Python 3.13)

=== Phase 1: Build and Validate (vLLM 0.11.0) ===
[INFO] Building wheels for vLLM 0.11.0...
[SUCCESS] Wheel built successfully

=== Wheel Verification (vLLM 0.11.0) ===
[SUCCESS] Wheel verification passed

=== Phase 2: Production Publish (vLLM 0.11.0) ===
[SUCCESS] Published to production PyPI

=== Phase 3: GitHub Release (vLLM 0.11.0) ===
[SUCCESS] GitHub release created: v0.11.0-cpu
```

## When Things Are Skipped

```bash
# Already published
[WARNING] Version 0.11.0 already exists on pypi.org
[INFO] Skipping - already published

# Already released
[WARNING] GitHub release v0.11.0-cpu already exists
[WARNING] Skipping GitHub release creation

# Verification failed - auto rebuild
[WARNING] Wheel verification failed (attempt 1/2)
[INFO] Rebuilding wheels...
```

## Troubleshooting Quick Fixes

### Build fails
```bash
# Check disk space
df -h

# Check dependencies
command -v uv jq twine
```

### Wheel verification fails
```bash
# Check wheel manually
unzip -t dist/vllm_cpu-0.11.0-*.whl
twine check dist/vllm_cpu-0.11.0-*.whl

# Examine wheel contents
unzip -l dist/vllm_cpu-0.11.0-*.whl | head -50
```

### GitHub release fails
```bash
# Check authentication
gh auth status

# Re-authenticate
gh auth login
```

### Version already exists
```bash
# Check what's published
pip index versions vllm-cpu

# List GitHub releases
gh release list
```

## Time Estimates

| Task | Time |
|------|------|
| Build single variant | 30-60 min |
| Build all variants | 2.5-5 hours |
| Wheel verification | <1 min |
| Production publish | 1-2 min |
| GitHub release | <1 min |
| **Total (new release)** | **35-65 min** |
| **Total (existing wheel)** | **2-5 min** |

## Environment Setup

```bash
# Required tools
sudo apt install jq zip unzip
pip install twine uv
gh auth login

# API token in .env
cat > .env <<EOF
PYPI_API_TOKEN=pypi-...
EOF

# Secure permissions
chmod 600 .env

# Verify
ls -l .env  # Should be: -rw-------
```

## All Available Options

```bash
--variant=NAME           # vllm-cpu, vllm-cpu-avx512, etc., or "all"
--vllm-versions=X.Y.Z    # vLLM version(s) to build (required)
--python-versions=3.X    # Python version(s) (default: 3.13)
--version-suffix=SUFFIX  # Version suffix for re-uploads (.post1, .post2, .dev1)
--builder=TYPE           # native or docker (default: native)
--platform=PLATFORM      # auto, linux/amd64, linux/arm64 (docker only)
--dist-dir=DIR           # Output directory (default: dist)
--max-jobs=N             # Parallel build jobs
--skip-build             # Use existing wheel
--skip-github            # Skip GitHub release
--update-readme          # Update README in existing wheels only
--dry-run                # Preview only
--help                   # Show help
```

## Common Workflows

### New Release
```bash
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0
```

### Re-run After Failure
```bash
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-build
```

### Preview Only
```bash
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --dry-run
```

### PyPI Only (No GitHub Release)
```bash
./test_and_publish.sh --variant=vllm-cpu --vllm-versions=0.11.0 --skip-github
```

### Update README Only
```bash
./test_and_publish.sh --update-readme --variant=all --vllm-versions=0.11.0
```

### Re-upload Deleted Wheel (PyPI Filename Policy)
PyPI has an immutable filename policy - once a filename is used (even if deleted), it cannot be re-used. Use `--version-suffix` to create a new version with a PEP 440 compliant suffix:

```bash
# Re-upload as 0.10.0.post1 (new filename, installable as 0.10.0.post1)
./test_and_publish.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --version-suffix=.post1

# If .post1 was also deleted, use .post2, .post3, etc.
./test_and_publish.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --version-suffix=.post2
```

**Valid suffixes**: Only `.postN` and `.devN` are PEP 440 compliant for PyPI uploads.

## Documentation

| File | What It Covers |
|------|----------------|
| `TEST_AND_PUBLISH.md` | Complete user guide |
| `BUILD_ALL_VARIANTS.md` | Build process |
| `PYPI_PUBLISHING_GUIDE.md` | Publishing details |
| `QUICK_REFERENCE.md` | This file |

## Success Criteria

All these should show `[SUCCESS]`:
- Wheel built (or skipped if exists)
- Wheel validated with twine
- Wheel verification passed (ZIP, structure, metadata)
- Published to production PyPI (or skipped if exists)
- GitHub release created (or skipped if exists)

---

**Quick Help**: `./test_and_publish.sh --help`
**Full Docs**: See `TEST_AND_PUBLISH.md`
**Version**: 3.0.0
