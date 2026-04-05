# Plan: Apply fixes to cpu-non-unified-build branch

## Context
- Branch: `cpu-non-unified-build` at commit `0e626ed` (Dec 24, 2025)
- Old 5-variant wheel build system (noavx512, avx512, avx512vnni, avx512bf16, amxbf16)
- Target versions: v0.15.0 and v0.16.0 (last releases before unified build)
- Main branch has unified build for v0.17.0+

## Phase 1: Core Fixes

### Docker Fixes (D1-D6) — apply to docker/Dockerfile + docker/cleanup.sh

| ID | Fix | File | Details |
|----|-----|------|---------|
| D1 | OpenTelemetry propagators broken on Python 3.13 | `docker/Dockerfile` | Add `ENV OTEL_PROPAGATORS=none` and `ENV OTEL_TRACES_EXPORTER=none` |
| D2 | Empty string env vars break int parsing | `docker/Dockerfile` | Set `VLLM_USE_AOT_COMPILE=0` and `VLLM_DISABLE_COMPILE_CACHE=0` instead of `""` |
| D3 | g++ symlink points to C++ Module Mapper not compiler | `docker/cleanup.sh` | Fix symlink to `x86_64-linux-gnu-g++-*` (actual compiler, not mapper) |
| D4 | cleanup.sh removes torch/include via `find -name "include"` | `docker/cleanup.sh` | Remove `-o -name "include"` from find command; also comment out explicit `rm torch/include` line |
| D5 | CPU torch wheel missing inductor headers | New: `docker/restore_torch_headers.sh` | Downloads headers from matching CUDA wheel via PyPI JSON API + curl |
| D6 | pip/uv removed by cleanup before header restore | `docker/restore_torch_headers.sh` | Uses curl + python3 urllib (not pip/uv) for download |

**Implementation:** Copy `restore_torch_headers.sh` from main branch. Apply D1-D2 edits to Dockerfile. Apply D3-D4 edits to cleanup.sh. Add COPY+RUN for restore script in Dockerfile AFTER cleanup layer.

### Wheel Fixes

| ID | Fix | File | Details |
|----|-----|------|---------|
| W-ABI | Stable ABI cp38-abi3 | `build_wheels.sh` | Add `--py-limited-api=cp38` to build command. Upstream confirms abi3 works on v0.14.0+ |
| W-PY | Pin Python 3.12 for building | `_build-wheel-job.yml` + `build_wheels.sh` | Remove Python version matrix, use single cp312 for all builds |
| W4 | Platform detection patch | `build_wheels.sh` | Patch `vllm/platforms/__init__.py` during build to fallback from `version("vllm")` to checking all 5 `vllm-cpu-*` variant package names |
| W-DEP | Deprecation notice on 4 variant packages | `avx512_README.md`, `avx512vnni_README.md`, `avx512bf16_README.md`, `amxbf16_README.md` | "v0.16.0 is the last release. Migrate to `pip install vllm-cpu` for v0.17.0+" |
| W-INFO | Info notice on vllm-cpu | `noavx512_README.md` | "Starting v0.17.0, unified build with auto ISA detection. See github.com/MekayelAnik/vllm-cpu" |

**Already handled (no change needed):**
- W3: SETUPTOOLS_SCM_PRETEND_VERSION — already at line 1238 of build_wheels.sh

### What stays unchanged
- 5 variant packages (vllm-cpu, vllm-cpu-avx512, etc.)
- 5 PyPI tokens
- Variant-specific Docker images (noavx512-latest, avx512-latest, etc.)
- Old workflow structure (_check-versions.yml, _build-wheel-job.yml, _publish-pypi.yml)
- build_and_verify.sh publish logic (already handles PEP 639)

## Phase 2: Smoke Tests

### Wheel smoke test (add to `_build-wheel-job.yml`)
After wheel build + glibc verify, add steps:
1. Create temp venv on the runner
2. Install wheel + torch CPU + tcmalloc + libiomp5 (x86 only)
3. Set VLLM_TARGET_DEVICE=cpu, OTEL_PROPAGATORS=none
4. Create vllm dist-info shim for platform detection
5. Test 1: `import vllm` + version check
6. Test 2: ISA detection (AVX2/AVX512/NEON features)
7. Test 3: `from vllm import LLM, SamplingParams`
8. Test 4: Package metadata check
9. Test 5: End-to-end inference with SMOKE_TEST_MODEL (default: facebook/opt-125m)

### Docker smoke test (add to both branches)

**On `cpu-non-unified-build`:** Add to `build-docker-image.yml` after image push:
1. Pull the just-built image
2. Run inference test with facebook/opt-125m inside container
3. Verify output tokens > 0

**On `main`:** Add to `monitor-pypi-releases.yml` after build-versions succeeds:
1. Pull `ghcr.io/mekayelanik/vllm-cpu:{version}` 
2. Run inference test with SMOKE_TEST_MODEL
3. Verify output tokens > 0

## Build matrix after changes

### Before (per version):
- 5 variants × 2 platforms × N python versions = ~30-50 wheels
- 5 variant Docker images × 2 platforms = 10 Docker manifests

### After (per version):
- 5 variants × 2 platforms × 1 (abi3) = **10 wheels**
- 5 variant Docker images × 2 platforms = 10 Docker manifests (unchanged)
- Smoke tests on every wheel build + Docker build

## Key references
- Main branch fixes: see memory files `project_wheel_build_fixes.md` and `project_docker_image_fixes.md`
- Old build scripts: `build_wheels.sh`, `build_and_verify.sh` at commit 0e626ed
- Upstream abi3 confirmation: v0.14.0+, v0.15.0, v0.16.0 all ship cp38-abi3 wheels
- restore_torch_headers.sh: copy from main branch HEAD
- Platform detection: `vllm/platforms/__init__.py` uses `version("vllm")` — same in v0.15.0 and v0.17.0+

## GHA cache warning
The reusable-build-versions.yml cache scope may need bumping after Docker fixes (same issue as main branch). Current scope pattern: `vllm-cpu-{version}-{slug}`. May need to change to `vllm-cpu-v2-{version}-{slug}` if cached cleanup layers persist.
