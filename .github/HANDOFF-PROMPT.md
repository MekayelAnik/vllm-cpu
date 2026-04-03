# vllm-cpu Repository -- Comprehensive Handoff Prompt

## Project Overview

**Repository**: `MekayelAnik/vllm-cpu`
**Purpose**: Builds unified vLLM CPU wheels (1 package × 2 platforms × multiple Python versions) AND Docker images. Pushes to PyPI, GitHub Releases, Docker Hub, and GHCR.
**Maintainer**: Mohammad Mekayel Anik
**PyPI package**: `vllm-cpu` (single unified package)
**Docker image**: `mekayelanik/vllm-cpu` (DH) + `ghcr.io/mekayelanik/vllm-cpu` (GHCR)

### Current State (as of commit 5284286)

The repo has been **partially migrated** to the split-runner reusable workflow pattern (used in brave-search-mcp-docker and other repos). The NEW infrastructure is in place:

- `.github/workflows/reusable-build-versions.yml` -- reusable build workflow (NEW)
- `.github/workflows/reusable-promote-latest.yml` -- reusable promote workflow (NEW)
- `.github/actions/resolve-build-profile/action.yml` -- composite action (NEW)
- `.github/actions/setup-build-env/action.yml` -- composite action (NEW)
- `.github/actions/promote-latest/action.yml` -- composite action (NEW)
- `.github/actions/registry-sync/action.yml` -- composite action (NEW)
- `.github/actions/registry-login/action.yml` -- composite action (NEW)
- `.github/actions/preflight-shell-tests/action.yml` -- composite action (NEW)
- `.github/scripts/` -- 8 helper shell scripts (NEW)

But the OLD caller workflows have been **deleted** and **no new caller workflow exists yet**. The old callers were removed at some point after commit ae85e87. The repo currently has NO top-level caller workflow -- only the two reusable workflows.

### CRITICAL: Upstream Unified CPU Wheel (PR #35466, merged Feb 28 2026)

vllm-project/vllm PR #35466 merged a **unified CPU wheel** that contains both AVX2 and AVX512 code in a single binary. Key details:

- **How it works**: The wheel ships two `.so` files (`_C.so` for AVX512+BF16+VNNI+AMX, `_C_AVX2.so` for AVX2). At import time, `vllm/platforms/cpu.py` checks `torch._C._cpu._is_avx512_supported()` and loads the correct one. Zero runtime dispatch overhead.
- **First release with unified build**: v0.17.0 (released 2026-03-07). The PR was merged Feb 28 into main, v0.16.0 was released Feb 25 (before merge). So **v0.17.0 is the first unified version.**
- **Impact**: The old 5-variant approach (noavx512, avx512, avx512vnni, avx512bf16, amxbf16) is **obsolete** for v0.17.0+

### CRITICAL: Upstream Now Publishes Official CPU Wheels

Starting v0.17.0, vllm-project publishes official CPU wheels on GitHub Releases:

```
vllm-0.17.0+cpu-cp38-abi3-manylinux_2_35_x86_64.whl  (54MB, 334 downloads)
vllm-0.17.0+cpu-cp38-abi3-manylinux_2_35_aarch64.whl  (33MB, 44 downloads)
```

**Key facts about upstream wheels:**
- **`cp38-abi3` (Stable ABI)**: Works with Python 3.8+. No per-Python-version builds needed.
- **`+cpu` local version suffix**: PEP 440 local versions CANNOT be uploaded to PyPI. Only available from GitHub Releases.
- **`manylinux_2_35`**: Requires glibc 2.35 (Ubuntu 22.04+). Less compatible than manylinux_2_28.
- **GitHub Releases only**: NOT on PyPI. Users must install via direct URL: `pip install "vllm @ https://github.com/vllm-project/vllm/releases/download/v0.17.0/vllm-0.17.0+cpu-cp38-abi3-manylinux_2_35_x86_64.whl"`

**Your value-add (what upstream DOESN'T provide):**
1. **PyPI availability** — `pip install vllm-cpu` (upstream can't put +cpu wheels on PyPI)
2. **Docker images** — pre-configured with tcmalloc, OMP binding, NUMA optimization, CPU variant detection, health checks
3. **Broader glibc support** — manylinux_2_28 (glibc 2.28, Debian 10+/Ubuntu 18.04+) vs upstream's manylinux_2_35
4. **Simple install** — no need to copy long GitHub URLs

### Decision: Two options for the wheel pipeline

**Option A: Build your own unified wheels (RECOMMENDED)**
- Build from vLLM source like before, but unified (no 5 variants)
- Target manylinux_2_28 for broader compatibility
- Publish to PyPI as `vllm-cpu` (single package, one token)
- Also upload to GitHub Releases
- Users get `pip install vllm-cpu` which just works

**Option B: Repackage upstream wheels (simpler but less control)**
- Download official `+cpu` wheels from GitHub Releases
- Strip the `+cpu` suffix and repackage as `vllm-cpu`
- Publish to PyPI
- Downside: tied to upstream's manylinux_2_35, no glibc control

### Strategy: Unified Build Only (v0.17.0+)

- **Stop building old 5-variant wheels.** Existing packages on PyPI remain available for users on v0.8.5-v0.15.x.
- **One PyPI package**: `vllm-cpu` — unified wheel per platform (x86_64, aarch64). With stable ABI (cp38-abi3), possibly only 1 wheel per platform (no per-Python builds needed).
- **One Docker image**: `mekayelanik/vllm-cpu` — multi-arch manifest (linux/amd64 + linux/arm64)
- **One PyPI token** instead of 5
- **Tags**: `vllm-cpu:X.Y.Z` (version), `vllm-cpu:latest`, `vllm-cpu:stable`
- **Minimum version**: v0.17.0 (first release with unified CPU build)

### What Needs to Be Built

**Two caller workflows:**

**1. `monitor-pypi-releases.yml` — Docker image pipeline** (use codegraphcontext-mcp-docker as PRIMARY reference)
- Detect new vLLM releases on PyPI (v0.16.0+ only)
- Build multi-arch Docker images via `reusable-build-versions.yml`
- Push to GHCR (primary) + Docker Hub (secondary) via `registry-sync`
- Promote latest/stable via `reusable-promote-latest.yml`
- Pipeline-state branch for skip-if-unchanged optimization
- Schedule + workflow_dispatch + repository_dispatch triggers

**2. `build-wheel.yml` — PyPI wheel pipeline** (restore from ae85e87 and simplify)
- Detect new vLLM releases (same version detection as Docker pipeline)
- Build unified wheels in manylinux_2_28 containers (x86_64 + aarch64)
- Publish to PyPI (single `vllm-cpu` package, one token)
- Upload to GitHub Releases
- Multiple Python versions (auto-detect or manual override)
- The wheel build MUST happen before Docker build (Docker images install the wheel from PyPI)

**Pipeline flow**: Version detect → Build wheels → Publish to PyPI + GitHub Releases → Build Docker images → Push to GHCR + DH → Promote latest/stable

### What Changes from the Old Architecture

| Aspect | Old (v0.8.5-v0.15.x) | New (v0.17.0+) | Upstream official |
|--------|----------------------|----------------|-------------------|
| PyPI packages | 5 (`vllm-cpu-noavx512`, etc.) | 1 (`vllm-cpu`) | None (can't publish +cpu to PyPI) |
| PyPI tokens | 5 (one per variant) | 1 | N/A |
| Docker variants | 5 image tags per version | 1 multi-arch image | `vllm/vllm-openai` (CUDA only) |
| ISA selection | User picks variant at install | Runtime auto-detection | Runtime auto-detection |
| Build matrix | 5 variants × 2 platforms × N python | 2 platforms (stable ABI = 1 wheel each) | 2 platforms |
| Wheel content | Single ISA per wheel | AVX2 + AVX512 .so files | AVX2 + AVX512 .so files |
| glibc requirement | manylinux_2_28 (glibc 2.28) | manylinux_2_28 (broader compat) | manylinux_2_35 (glibc 2.35) |
| Python ABI | Per-version (cp310, cp311, etc.) | Stable ABI cp38-abi3 (all 3.8+) | Stable ABI cp38-abi3 |
| Install method | `pip install vllm-cpu-avx512` | `pip install vllm-cpu` | Manual URL from GH Releases |
| Version range | v0.8.5+ | v0.17.0+ only | v0.17.0+ |

---

## OLD Architecture (commit ae85e87, now deleted)

### Old Caller Workflows

#### 1. `build-wheel.yml` -- Auto-Build vLLM CPU Wheels

**Triggers**:
```yaml
on:
  schedule:
    - cron: '5 * * * *'   # Every hour at :05
  workflow_dispatch:
    inputs:
      vllm_versions:
        description: 'vLLM versions (e.g., 0.12.0 or 0.11.2,0.12.0 or 0.11.0-0.12.0)'
        type: string
        default: ''
      python_versions:
        description: 'Python versions (optional, e.g., 3.12 or 3.10-3.13)'
        type: string
        default: 'auto'
      build_noavx512:    # boolean, default: true
      build_avx512:      # boolean, default: true
      build_avx512vnni:  # boolean, default: true
      build_avx512bf16:  # boolean, default: true
      build_amxbf16:     # boolean, default: true
      platforms:         # choice: all, linux/amd64, linux/arm64
      skip_pypi:         # boolean, default: false
      skip_github_release: # boolean, default: false
      dry_run:           # boolean, default: false
      version_postfix:   # string (e.g., .post1, .dev2, .rc1)
```

**Concurrency**: `wheel-scheduled` for schedule, `wheel-manual-{run_id}` for manual

**Job Chain**:
```
check-versions --> build (matrix) --> publish (matrix per version) --> github-release (matrix per version) --> summary
```

**Key Outputs from check-versions**:
- `build_matrix` -- JSON matrix for `fromJSON()` with fields: variant, platform, version, python_version
- `has_builds` -- boolean
- `new_versions` -- JSON array of version strings
- `version_postfix` -- normalized postfix
- `build_amd64`, `build_arm64` -- booleans

**5 ISA Variants**:
| Variant | Package Name | Platforms |
|---------|-------------|-----------|
| noavx512 | vllm-cpu | AMD64 + ARM64 |
| avx512 | vllm-cpu-avx512 | AMD64 only |
| avx512vnni | vllm-cpu-avx512vnni | AMD64 only |
| avx512bf16 | vllm-cpu-avx512bf16 | AMD64 only |
| amxbf16 | vllm-cpu-amxbf16 | AMD64 only |

#### 2. `build-docker-image.yml` -- Auto-Build vLLM CPU Docker Images

**Triggers**:
```yaml
on:
  schedule:
    - cron: '35 * * * *'   # Every hour at :35
  workflow_dispatch:
    inputs:
      vllm_versions:       # string
      python_version:      # string (single version)
      build_noavx512:      # boolean
      build_avx512:        # boolean
      build_avx512vnni:    # boolean
      build_avx512bf16:    # boolean
      build_amxbf16:       # boolean
      platforms:           # choice: all, linux/amd64, linux/arm64
      use_github_release:  # boolean
      version_postfix:     # string
      use_highest_postfix: # boolean
      skip_dockerhub:      # boolean
      skip_ghcr:           # boolean
      force_rebuild_dockerhub: # boolean
      force_rebuild_ghcr:  # boolean
      skip_latest_tag:     # boolean
      dry_run:             # boolean
      no_cache:            # boolean
      compression:         # choice: zstd, gzip, uncompressed
      compression_level:   # string
```

**Concurrency**: `docker-scheduled` for schedule, `docker-manual-{run_id}` for manual

**Image names**:
- Docker Hub: `mekayelanik/vllm-cpu`
- GHCR: `ghcr.io/mekayelanik/vllm-cpu`

**Docker tag format**: `{version}-{variant}` and `{variant}-{version}` (both directions)

**Job Chain**:
```
check-versions (_check-versions-docker.yml) --> build-images (matrix) --> update-latest-tags (matrix per variant)
```

#### 3. `_check-versions.yml` -- Reusable Version Check (Wheel)

**Type**: `workflow_call`

**Inputs**:
```yaml
inputs:
  vllm_versions:     # string -- manual version spec
  build_noavx512:    # boolean
  build_avx512:      # boolean
  build_avx512vnni:  # boolean
  build_avx512bf16:  # boolean
  build_amxbf16:     # boolean
  platforms:         # string (all, linux/amd64, linux/arm64)
  version_postfix:   # string
  skip_pypi:         # boolean
  skip_github_release: # boolean
```

**Outputs**:
```yaml
outputs:
  build_matrix:      # JSON matrix with: variant, platform, version, python_version
  has_builds:        # boolean string
  new_versions:      # JSON array of version strings
  version_postfix:   # normalized postfix
  build_amd64:       # boolean string
  build_arm64:       # boolean string
```

**Key Logic**:
1. Fetches vLLM releases from GitHub API (>= 0.8.5)
2. Fetches existing vllm-cpu versions from PyPI
3. Parses version input (supports ranges like `0.11.0-0.12.0`, lists, mixed)
4. Determines supported Python versions per vLLM version (reads upstream pyproject.toml)
5. Checks if specific wheels already exist on PyPI per python_tag + platform_tag
6. Generates cross-product matrix: versions x variants x platforms x python_versions

#### 4. `_check-versions-docker.yml` -- Reusable Version Check (Docker)

**Type**: `workflow_call`

**Additional Docker-specific inputs**:
```yaml
inputs:
  use_highest_postfix: # boolean
  use_github_release:  # boolean
  skip_dockerhub:      # boolean
  skip_ghcr:           # boolean
  force_rebuild_dockerhub: # boolean
  force_rebuild_ghcr:  # boolean
  dockerhub_image:     # string, default: 'mekayelanik/vllm-cpu'
  ghcr_image:          # string, default: 'ghcr.io/mekayelanik/vllm-cpu'
```

**Additional Docker-specific outputs**:
```yaml
outputs:
  latest_version:       # string
  needs_latest_update:  # boolean string
  use_github_release:   # boolean string
  variants_matrix:      # JSON array of variant strings
```

**Key Logic**:
1. Calls `_check-versions.yml` internally for base version parsing
2. Checks Docker Hub and GHCR for existing images per variant per platform
3. Detects highest .postN wheel version from PyPI
4. Compares PyPI wheel publish date vs Docker image last_updated to detect rebuild needs
5. Checks platform parity across registries (DH and GHCR must both have all platforms)

#### 5. `_build-wheel-job.yml` -- Reusable Wheel Build

**Type**: `workflow_call`

**Inputs**:
```yaml
inputs:
  variant:          # string, required (noavx512, avx512, etc.)
  platform:         # string, required (amd64, arm64)
  version:          # string, required
  python_versions:  # string, default: 'auto'
  version_postfix:  # string
  skip_github_release: # boolean
  skip_glibc_verify:   # boolean
  uv_version:       # string, default: 'latest'
```

**Outputs**:
```yaml
outputs:
  artifact_name:    # string
  wheel_count:      # number as string
  success:          # boolean string
```

**Key Details**:
- Uses native runners: `ubuntu-24.04-arm` for arm64, `ubuntu-latest` for amd64
- Builds inside `manylinux_2_28` containers (glibc 2.28 compat)
- Uses ccache and uv caching
- Uploads wheels as artifacts AND to GitHub Releases via softprops/action-gh-release
- Timeout: 300min arm64, 240min amd64
- Concurrency: `build-wheel-{workflow}-{ref}-{variant}-{platform}`

#### 6. `_publish-pypi.yml` -- Reusable PyPI Publish

**Type**: `workflow_call`

**Inputs**:
```yaml
inputs:
  version:          # string, required
  version_postfix:  # string
```

**Secrets** (all optional):
```yaml
secrets:
  PYPI_TOKEN_CPU:
  PYPI_TOKEN_AVX512:
  PYPI_TOKEN_AVX512VNNI:
  PYPI_TOKEN_AVX512BF16:
  PYPI_TOKEN_AMXBF16:
  PYPI_API_TOKEN:
```

**Outputs**:
```yaml
outputs:
  published_variants: # comma-separated string
  success:            # true/partial/false
```

**Key Details**:
- Downloads wheel artifacts by pattern `wheels-*-{version}{postfix}`
- Publishes each variant separately using `build_and_verify.sh`
- Maps variant to wheel filename pattern

#### 7. `_update-release-notes.yml` -- Reusable Release Notes

**Type**: `workflow_call`

**Inputs**: `version` (string), `version_postfix` (string)
**Outputs**: `success` (boolean string)

Generates markdown table of all wheel variants with pip install commands and updates GitHub Release body.

#### 8. `schedule-keeper.yml` -- Backup Trigger

**Triggers**:
```yaml
on:
  schedule:
    - cron: '10,40 * * * *'   # Twice per hour
  workflow_dispatch:
    inputs:
      trigger_wheels:  # boolean, default: true
      trigger_docker:  # boolean, default: true
```

Checks if main workflows ran in last 2 hours via GitHub API. If not, dispatches them. Prevents silent schedule failures.

#### 9. `keep-alive.yml` -- Anti-Disable

**Triggers**:
```yaml
on:
  schedule:
    - cron: '0 0 1,15 * *'   # 1st and 15th of each month
  workflow_dispatch:
```

Commits a timestamp file if no real commits in 30+ days. Prevents GitHub from disabling scheduled workflows.

---

## NEW Architecture (current HEAD, 5284286)

### Reusable Workflows

#### `reusable-build-versions.yml` -- Reusable Build Versions

**Type**: `workflow_call`

**Inputs**:
```yaml
inputs:
  versions_json:           # string, required -- JSON matrix include payload
  build_profile:           # string, default: 'production'
  force_build:             # string, default: 'false'
  base_image_default:      # string, required
  ghcr_repo:               # string, required
  dockerhub_repo:          # string, required
  default_platforms:        # string, required -- e.g. 'linux/amd64,linux/arm64'
  export_cache_concurrency: # string, default: '4'
  export_layers_concurrency: # string, default: '4'
  buildkit_step_log_max_size:  # string, default: '50000000'
  buildkit_step_log_max_speed: # string, default: '100000000'
  buildkit_progress:        # string, default: 'plain'
  docker_buildkit_inline_cache: # string, default: '1'
  runner_version:           # string, default: 'ubuntu-24.04'
```

**Secrets**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` (both required)

**Permissions**: `contents: read`, `packages: write`

**Jobs**:

1. **prepare-matrix** -- Generates version x platform cross-product
   - Takes `versions_json` input and `default_platforms`
   - Platform-to-runner affinity table:
     ```
     linux/amd64   -> {runner_version}         slug: amd64
     linux/arm64   -> {runner_version}-arm      slug: arm64
     linux/arm/v7  -> {runner_version}-arm      slug: armv7
     linux/arm/v6  -> {runner_version}-arm      slug: armv6
     linux/riscv64 -> {runner_version}-riscv    slug: riscv64
     linux/386     -> {runner_version}          slug: 386
     linux/s390x   -> {runner_version}          slug: s390x
     linux/ppc64le -> {runner_version}          slug: ppc64le
     linux/mips64le -> {runner_version}         slug: mips64le
     ```
   - Outputs: `matrix` (JSON with include array), `versions` (deduplicated version list)

2. **build-platform** -- Per-platform build (needs: prepare-matrix)
   - Runs on: `matrix.runner` (native or QEMU-emulated)
   - Concurrency: `build-{version}-{slug}`, no cancel
   - Max parallel: 8, fail-fast: false
   - Steps: checkout -> resolve-build-profile -> setup-build-env -> check-existing-tags -> DockerfileModifier.sh -> docker/build-push-action (push-by-digest) -> upload digest artifact
   - Uses GHA cache per version+slug scope
   - Build args: `BUILDKIT_INLINE_CACHE=1`, `VLLM_VERSION`, `BASE_IMAGE`
   - Output: `Dockerfile.vllm-cpu` (generated)

3. **merge-manifest** -- Merge per-platform digests (needs: prepare-matrix, build-platform)
   - Runs if: `!cancelled() && prepare-matrix succeeded`
   - Strategy: matrix over deduplicated versions
   - Downloads digest artifacts, creates multi-arch manifest with `docker buildx imagetools create`
   - Tags: `{ghcr_repo}:{version}`, `{ghcr_repo}:{image_tag}`, `{dockerhub_repo}:{version}`, `{dockerhub_repo}:{image_tag}`
   - Runs registry-sync action as fallback parity check

**versions_json Expected Format**:
```json
[
  {"version": "0.14.0", "image_tag": "0.14.0-20250403", "promote_latest": true},
  {"version": "0.13.2", "image_tag": "0.13.2-20250403", "promote_latest": false}
]
```

#### `reusable-promote-latest.yml` -- Reusable Promote Latest

**Type**: `workflow_call`

**Inputs**:
```yaml
inputs:
  latest_version:    # string, required
  date_tag:          # string, required (e.g. DDMMYYYY)
  ghcr_repo:         # string, required
  dockerhub_repo:    # string, required
  force_latest:      # boolean, default: false
  force_stable:      # boolean, default: false
  runner_version:    # string, default: 'ubuntu-24.04'
```

**Secrets**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` (both required)

**Job**: promote-latest
- Uses promote-latest composite action
- Handles: latest tag promotion + stable tag promotion (5-day soak rule)
- Uses crane for HEAD-only digest checks (efficient API usage)
- Rate-limit tolerant (returns rc=2 on 429)

### Composite Actions

#### `resolve-build-profile`
**Inputs**: `build_profile` (production/ci/development/size-optimized)
**Outputs**: `compression_type`, `compression_level`, `compression_params`

| Profile | Type | Level |
|---------|------|-------|
| production | zstd | 22 |
| ci | zstd | 3 |
| development | gzip | 1 |
| size-optimized | gzip | 9 |

#### `setup-build-env`
**Inputs**: `do_checkout`, `setup_qemu`, `setup_buildx`, `login_dockerhub`, `login_ghcr`, `dockerhub_username`, `dockerhub_token`, `ghcr_actor`, `ghcr_token`, `install_crane`

**BuildKit config** (hardcoded):
- DNS: 1.1.1.1, 76.76.2.0, 95.161.161.161, 8.8.8.8
- ndots:0, attempts:2, timeout:3
- worker.oci: max-parallelism=4, gc=true, reservedSpace=2GB, maxUsedSpace=12GB
- Docker.io mirror: mirror.gcr.io
- BuildKit image: `moby/buildkit:master`

**Crane install**: Fetches latest via GitHub API (authenticated), falls back to pinned versions (v0.21.3, v0.21.2, v0.21.1, v0.20.3).

#### `promote-latest`
**Inputs**: `latest_version`, `date_tag`, `ghcr_repo`, `dockerhub_repo`, `gh_token`, `github_repository`, `force_latest`, `force_stable`
**Outputs**: `source_tag_ghcr`, `skipped`, `stable_promoted`

**Latest promotion logic**:
1. Resolve source tag: try `{version}-{date_tag}` first, fall back to `{version}`
2. Check if GHCR `:latest` already matches source digest (HEAD-only via crane)
3. Check Docker Hub parity
4. If not matched: `crane tag` on GHCR, `crane copy` to Docker Hub
5. Verify post-promotion digests

**Stable promotion logic (5-day rule)**:
1. Read `state.json` from `pipeline-state` branch via GitHub API
2. Check `latest_version_since` timestamp
3. If >= 5 days as `:latest`, promote to `:stable`
4. Same crane tag/copy pattern for GHCR and Docker Hub

#### `registry-sync`
**Inputs**: `dockerhub_repo`, `ghcr_repo`, `tags` (comma-separated)
Delegates to `.github/scripts/registry-sync.sh`

#### `registry-login`
**Inputs**: `dockerhub_username`, `dockerhub_token`, `ghcr_actor`, `ghcr_token`, `push_to_dockerhub`, `push_to_ghcr`
Uses `docker/login-action@v4` for both registries.

#### `preflight-shell-tests`
No inputs. Delegates to `.github/scripts/preflight-shell-tests.sh`

### Helper Scripts (`.github/scripts/`)

| Script | Purpose |
|--------|---------|
| `check-existing-tags.sh` | Check if Docker tags already exist in GHCR |
| `fetch-releases.sh` | Fetch and filter releases from upstream registry |
| `lib-retry.sh` | Shared retry helper functions |
| `normalize-dispatch-inputs.sh` | Normalize workflow_dispatch and repository_dispatch inputs |
| `preflight-shell-tests.sh` | Shell syntax and behavior validation |
| `registry-sync.sh` | Sync tags between GHCR and Docker Hub |
| `test-registry-sync.sh` | Tests for registry-sync |
| `test-runtime-behavior.sh` | Tests for runtime behavior |

---

## Gold Standard: PyPI-Based Caller (codegraphcontext-mcp-docker)

This is the **PRIMARY** reference for vllm-cpu because it uses PyPI (not npm). Source: `codegraphcontext-mcp-docker/.github/workflows/monitor-npm-releases.yml`.

### Environment Variables (PyPI Pattern)
```yaml
env:
  PYPI_PACKAGE: 'codegraphcontext'
  PYPI_REGISTRY: 'https://pypi.org'
  MAX_VERSIONS: '10'
  TZ: ${{ vars.TZ || 'Asia/Dhaka' }}
  PRIMARY_REGISTRY: 'ghcr'
  DOCKERHUB_REPO: ${{ vars.DOCKERHUB_REPO || 'mekayelanik/codegraphcontext-mcp' }}
  GHCR_REPO: ${{ vars.GHCR_REPO || format('ghcr.io/{0}/codegraphcontext-mcp', github.repository_owner) }}
  DEFAULT_PLATFORMS: ${{ vars.DEFAULT_PLATFORMS || 'linux/amd64,linux/arm64' }}
  EXCLUDE_VERSIONS: ${{ vars.EXCLUDE_VERSIONS || '' }}
  BASE_IMAGE_DEFAULT: ${{ github.event.inputs.base_image || vars.BASE_IMAGE_DEFAULT || 'python:3.13-slim' }}
  HAPROXY_IMAGE: ${{ vars.HAPROXY_IMAGE || 'haproxy:lts' }}
```

Note: Uses `python:3.13-slim` as base image (not `node:current-alpine` like npm repos).

### PyPI Version Detection Logic

**quick-check** compares PyPI latest against stored state:
```bash
# Query PyPI JSON API for latest version
CURRENT_PYPI_LATEST="$(curl -fsSL "${PYPI_REGISTRY}/pypi/${PYPI_PACKAGE}/json" \
  | jq -r '.info.version // ""' 2>/dev/null || echo "")"

# Read stored state from pipeline-state branch
STATE_JSON="$(gh api "repos/${REPO}/contents/${STATE_FILE}?ref=${STATE_BRANCH}" \
  --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo "")"
STORED_PYPI_LATEST="$(echo "$STATE_JSON" \
  | jq -r '.pypi_latest_version // .npm_latest_version // ""')"

# Compare: skip pipeline if unchanged
if [[ "$CURRENT_PYPI_LATEST" != "$STORED_PYPI_LATEST" ]]; then
  echo "should_run=true"
else
  echo "should_run=false"
fi
```

Key: The PyPI JSON API endpoint is `https://pypi.org/pypi/{PACKAGE}/json` -- the `.info.version` field gives the latest stable release.

### fetch-releases (PyPI)

Uses `fetch-releases-pypi.sh` script (not `fetch-releases.sh` used by npm repos):
```bash
PYPI_PACKAGE="${PYPI_PACKAGE}" \
PYPI_REGISTRY="${PYPI_REGISTRY}" \
MAX_VERSIONS="${MAX_VERSIONS}" \
EXCLUDE_VERSIONS="${EXCLUDE_VERSIONS}" \
bash .github/scripts/fetch-releases-pypi.sh
```

Outputs: `versions_json`, `latest_version`, `date_tag`, `should_build` -- same shape as npm variant.

### Job Chain (identical structure to npm caller)
```
quick-check --> preflight ---------> fetch-releases --> build-versions --> promote-latest --> update-state
                                          |                                      |              --> update-readme-version
                                          |                                      |              --> update-dockerhub-description
                                          +--------------------------------------+
```

### update-state (PyPI field name)

Stores `pypi_latest_version` (not `npm_latest_version`) in `state.json`:
```json
{
  "pypi_latest_version": "1.2.3",
  "updated_at": "2025-04-01T12:00:00Z",
  "latest_version_since": "2025-03-28T08:00:00Z"
}
```

Note: The quick-check step reads both field names for backwards compat: `.pypi_latest_version // .npm_latest_version`.

### PyPI-Specific Patterns (differ from npm)

1. **API endpoint**: `https://pypi.org/pypi/{package}/json` vs `https://registry.npmjs.org/{package}`
2. **Version field**: `.info.version` (PyPI) vs `.dist-tags.latest` (npm)
3. **Script**: `fetch-releases-pypi.sh` vs `fetch-releases.sh`
4. **Base image**: `python:3.13-slim` vs `node:current-alpine`
5. **State field**: `pypi_latest_version` vs `npm_latest_version`
6. **Trigger type**: `repository_dispatch: [codegraphcontext-mcp-build]` (repo-specific)

### Adapting for vllm-cpu

codegraphcontext-mcp is a **simple case**: one PyPI package, one version, straightforward `.info.version` lookup. vllm-cpu is more complex:
- **5 variant packages** (vllm-cpu, vllm-cpu-avx512, etc.) -- need to query multiple PyPI packages
- **.postN versions** (e.g., `0.14.0.post1`, `0.14.0.post2`) -- need to parse all versions from PyPI, not just `.info.version`
- **Version list endpoint**: Use `https://pypi.org/pypi/{package}/json` and parse `.releases` keys to find all `.postN` variants
- **Highest postfix detection**: Must iterate `.releases` to find highest `.postN` for a given base version

---

## Gold Standard Caller Pattern (from brave-search-mcp-docker, npm-based)

The `monitor-npm-releases.yml` is the reference implementation for a unified caller workflow:

### Trigger Schema
```yaml
on:
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options: [auto-check, build, promote-latest, force-promote-latest, promote-stable, force-promote-stable]
        default: auto-check
      versions:
        description: 'Comma-separated, range, or empty for auto'
        type: string
        default: ''
      force_build:       # boolean
      auto_promote:      # boolean
      custom_latest:     # string
      build_profile:     # choice: production, ci, development, size-optimized
      base_image:        # string override
  repository_dispatch:
    types: [brave-search-mcp-build]
```

### Environment Variables Pattern
```yaml
env:
  NPM_PACKAGE: '@brave/brave-search-mcp-server'
  NPM_REGISTRY: 'https://registry.npmjs.org'
  MAX_VERSIONS: '10'
  TZ: ${{ vars.TZ || 'Asia/Dhaka' }}
  PRIMARY_REGISTRY: 'ghcr'
  DOCKERHUB_REPO: ${{ vars.DOCKERHUB_REPO || 'mekayelanik/brave-search-mcp' }}
  GHCR_REPO: ${{ vars.GHCR_REPO || format('ghcr.io/{0}/brave-search-mcp', github.repository_owner) }}
  DEFAULT_PLATFORMS: ${{ vars.DEFAULT_PLATFORMS || 'linux/amd64,linux/arm64' }}
  EXCLUDE_VERSIONS: ${{ vars.EXCLUDE_VERSIONS || '' }}
  BASE_IMAGE_DEFAULT: ${{ github.event.inputs.base_image || vars.BASE_IMAGE_DEFAULT || 'node:current-alpine' }}
```

### Job Chain
```
quick-check --> preflight ---------> fetch-releases --> build-versions --> promote-latest --> update-state
                                          |                                      |              --> update-readme-version
                                          |                                      |              --> update-dockerhub-description
                                          +--------------------------------------+
```

### Key Jobs

1. **quick-check**: Reads `pipeline-state` branch `state.json`, compares stored version with current registry latest. Skips entire pipeline if unchanged (for schedule triggers).

2. **preflight**: YAML validation + shell tests. Runs `.github/actions/preflight-shell-tests`.

3. **fetch-releases**: 
   - Normalizes dispatch inputs via script
   - Collects versions via `fetch-releases.sh`
   - Outputs: `normalized_action`, `normalized_versions`, `normalized_force_build`, `normalized_auto_promote`, `normalized_custom_latest`, `versions_json`, `latest_version`, `date_tag`, `should_build`

4. **build-versions**: Calls `reusable-build-versions.yml` with all params.
   - Condition: `should_build == 'true' && action not promote-*`

5. **promote-latest**: Calls `reusable-promote-latest.yml`
   - Complex condition handles: explicit promote actions, auto-promote after build, auto-check mode
   - Passes `force_latest` and `force_stable` based on action

6. **update-state**: Writes/updates `state.json` on `pipeline-state` branch
   - Fields: `npm_latest_version`, `updated_at`, `latest_version_since`
   - Preserves `latest_version_since` if version unchanged (for 5-day soak tracking)

7. **update-readme-version**: Updates version references in README.md and workflow file

8. **update-dockerhub-description**: Syncs README to Docker Hub via peter-evans/dockerhub-description

---

## Recommendation: Which Reference to Use

**Use codegraphcontext-mcp-docker as the PRIMARY reference** (PyPI-based). It shares the same package registry (PyPI), base image family (`python:*-slim`), state field naming (`pypi_latest_version`), and fetch script (`fetch-releases-pypi.sh`) that vllm-cpu needs.

**Use brave-search-mcp-docker as secondary reference** for npm-specific patterns only (e.g., if comparing job chain structure or reusable workflow interfaces that are registry-agnostic).

---

## Differences: vllm-cpu vs codegraphcontext-mcp vs brave-search-mcp

| Aspect | codegraphcontext-mcp (PyPI) | brave-search-mcp (npm) | vllm-cpu |
|--------|---------------------------|----------------------|----------|
| Upstream source | PyPI (`codegraphcontext`) | NPM registry | PyPI (vllm-cpu package) + GitHub releases (vllm-project/vllm) |
| Package type | Single PyPI package | Single npm package | 5 wheel variants x multiple Python versions |
| Docker variants | Single image | Single image | 5 Docker image variants (one per ISA) |
| Platforms | linux/amd64, linux/arm64 | linux/amd64, linux/arm64 | noavx512: amd64+arm64; others: amd64 only |
| Base image | `python:3.13-slim` | `node:current-alpine` | TBD (Python-based) |
| Version API | `pypi.org/pypi/{pkg}/json` `.info.version` | `registry.npmjs.org/{pkg}` `.dist-tags.latest` | `pypi.org/pypi/{pkg}/json` + `.releases` keys for .postN |
| Fetch script | `fetch-releases-pypi.sh` | `fetch-releases.sh` | `fetch-releases-pypi.sh` (adapted) |
| State field | `pypi_latest_version` | `npm_latest_version` | `pypi_latest_version` |
| Wheel building | N/A | N/A | Builds wheels inside manylinux_2_28 containers |
| PyPI publishing | N/A | N/A | Publishes 5 packages to PyPI with separate tokens |
| GitHub Releases | N/A | N/A | Creates releases with wheel assets |
| Docker tag format | `{version}` | `{version}` | `{version}-{variant}` and `{variant}-{version}` |
| Build complexity | Simple pip install | Simple npm install | Multi-stage: wheel build -> Docker image build |

### Critical vllm-cpu-Specific Concerns

1. **Wheel-then-Docker pipeline**: Wheels must be built first, then Docker images use them
2. **Per-Python-version checking**: Each Python version's wheel existence is checked independently
3. **.postN version handling**: PyPI may have 0.14.0.post1, 0.14.0.post2 etc. Docker tags use base version but install highest .postN wheel
4. **GitHub Release fallback**: Some versions may only exist as GitHub Releases (not on PyPI)
5. **5 separate PyPI tokens**: One per variant package
6. **Platform-variant matrix**: noavx512 builds for amd64+arm64, all others amd64-only
7. **manylinux_2_28 containers**: Wheel builds must use these for glibc compat
8. **ccache + uv caching**: Important for build performance
9. **GCC toolset 14**: Installed inside manylinux container for arm64 LTO fixes
10. **Schedule keeper**: Backup mechanism to re-trigger if schedules fail silently

---

## Action Versions Used

| Action | Version |
|--------|---------|
| actions/checkout | v6 |
| actions/upload-artifact | v7 |
| actions/download-artifact | v8 |
| actions/cache | v5 |
| docker/setup-qemu-action | v4 |
| docker/setup-buildx-action | v4 |
| docker/login-action | v4 |
| docker/build-push-action | v7 |
| docker/metadata-action | v5 |
| softprops/action-gh-release | v2 |
| peter-evans/dockerhub-description | v5 |

---

## Pipeline State Branch

The `pipeline-state` branch stores `state.json`:
```json
{
  "npm_latest_version": "1.2.3",
  "updated_at": "2025-04-01T12:00:00Z",
  "latest_version_since": "2025-03-28T08:00:00Z"
}
```

For vllm-cpu, the field name would likely change to `pypi_latest_version` or similar.

The `latest_version_since` tracks when a version first became `:latest`, used by the 5-day soak rule for `:stable` promotion.

---

## Repository Variables Expected

Based on the brave-search-mcp pattern and vllm-cpu specifics:

| Variable | Example Value | Purpose |
|----------|--------------|---------|
| `DOCKERHUB_REPO` | `mekayelanik/vllm-cpu` | Docker Hub image name |
| `GHCR_REPO` | `ghcr.io/mekayelanik/vllm-cpu` | GHCR image name |
| `DEFAULT_PLATFORMS` | `linux/amd64,linux/arm64` | Build platforms |
| `BASE_IMAGE_DEFAULT` | TBD | Base Docker image |
| `TZ` | `Asia/Dhaka` | Timezone |
| `ACTION_RUNNER_VERSION` | `ubuntu-24.04` | Runner version |
| `EXCLUDE_VERSIONS` | `` | Versions to skip |
| `MAX_VERSIONS` | `10` | Max versions to build |

## Repository Secrets Expected

| Secret | Purpose |
|--------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub login |
| `DOCKERHUB_TOKEN` | Docker Hub token |
| `PYPI_TOKEN_CPU` | PyPI token for vllm-cpu |
| `PYPI_TOKEN_AVX512` | PyPI token for vllm-cpu-avx512 |
| `PYPI_TOKEN_AVX512VNNI` | PyPI token for vllm-cpu-avx512vnni |
| `PYPI_TOKEN_AVX512BF16` | PyPI token for vllm-cpu-avx512bf16 |
| `PYPI_TOKEN_AMXBF16` | PyPI token for vllm-cpu-amxbf16 |
| `PYPI_API_TOKEN` | Fallback PyPI token |
| `GITHUB_TOKEN` | Auto-provided |

---

## Key Design Decisions to Make

1. **Unified or separate caller?** The old system had separate `build-wheel.yml` and `build-docker-image.yml`. The new system could unify them into a single caller (like brave-search-mcp) or keep them separate.

2. **Wheel build integration**: The current `reusable-build-versions.yml` is Docker-focused (uses DockerfileModifier.sh, push-by-digest). Wheel builds need a different reusable workflow or the old `_build-wheel-job.yml` pattern.

3. **Version detection source**: Old system checked GitHub releases (vllm-project/vllm). Should also check PyPI for .postN versions.

4. **Docker tag format**: Old format was `{version}-{variant}`. New reusable-build-versions uses `{version}` and `{image_tag}` from versions_json. Need to decide how variants map.

5. **Per-variant Docker images or single image?** Old system built 5 separate Docker images per variant. The new split-runner pattern typically builds one image. May need 5 separate calls to reusable-build-versions or a variant dimension in the matrix.
