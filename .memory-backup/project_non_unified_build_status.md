---
name: cpu-non-unified-build branch status
description: Status of fixes and releases on the old 5-variant build branch (v0.8.5-v0.16.0)
type: project
---

Branch `cpu-non-unified-build` — all fixes applied and published as of 2026-04-06.

**Published:**
- v0.15.1 wheels: all 5 variants (vllm-cpu, avx512, vnni, bf16, amx) on PyPI with cp38-abi3
- Docker v0.15.0: all 5 variant images on Docker Hub + GHCR

**Fixes applied (6 commits since 0e626ed):**
- D1-D6: All Docker fixes (OTEL, empty env vars, g++ symlink, include dirs, torch headers restore)
- W-ABI: Stable ABI cp38-abi3 (one wheel per variant per platform)
- W-PY: Build Python pinned to 3.13
- W4: Platform detection (cpu_platform_fix.py for all 5 variants)
- W-DEP: Deprecation notices on 4 variant packages
- W-INFO: Info notice on vllm-cpu about unified build v0.17.0+
- Smoke tests: wheel (noavx512 only) + Docker (noavx512 only)
- xgrammar pin relaxed to >=0.1.30

**Issues found during builds:**
- xgrammar 0.1.29 no cp313 aarch64 wheel → >=0.1.30
- GCC 14 arm64 false positive → CXXFLAGS=-Wno-error=free-nonheap-object
- torch+cpu resolution in smoke test → install from CPU index first
- SIGILL on avx512 variants in smoke test → restrict to noavx512 only

**Still TODO:**
- Publish v0.15.0, v0.16.0 wheels (v0.15.1 done, other versions pending)
- Docker images for v0.15.1 and v0.16.0

**How to apply:** Use `build_branch=cpu-non-unified-build` when triggering workflows for pre-v0.17.0 builds.
