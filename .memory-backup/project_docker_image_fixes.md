---
name: Docker image build and runtime fixes
description: All issues found and fixed for the vllm-cpu Docker image (build, runtime, inference)
type: project
---

Issues fixed for the vllm-cpu Docker image pipeline:

**DockerfileModifier.sh:**
1. Old modifier was from AgentDVR project template → rewrote to use docker/Dockerfile as template with sed substitution
2. Preflight test expected `FROM` in modifier → updated tests to check docker/Dockerfile instead
3. TARGETPLATFORM missing → added ARG to Dockerfile

**Docker build:**
4. `resources/setup.sh` not found → restored docker/ scripts from commit 0e626ed (setup_vllm.sh, entrypoint.sh, cleanup.sh, etc.)
5. COPY paths wrong (`detect_python_version.sh` vs `docker/detect_python_version.sh`) → prefix all COPY with `docker/`
6. Image too large (955MB vs 446MB) → switched base from `python:3.13-slim` to `debian:trixie-slim`, restored old optimized Dockerfile
7. Docker Hub push 400 Bad Request (digest-mismatch) → transient, retry fixed it
8. GHA cache serving stale layers despite code changes → changed cache scope (v1→v2→v3) to force rebuilds

**Runtime environment:**
9. OpenTelemetry propagator `tracecontext` not found (Python 3.13 entry_points broken) → `ENV OTEL_PROPAGATORS=none` + `ENV OTEL_TRACES_EXPORTER=none`
10. `VLLM_USE_AOT_COMPILE=""` empty string → int parse error → set to `0`
11. `VLLM_DISABLE_COMPILE_CACHE=""` same issue → set to `0`
12. g++ symlink pointed to C++ Module Mapper (wrong binary) → fixed to link to `x86_64-linux-gnu-g++-14`

**torch.compile / inductor:**
13. CPU torch wheel from `download.pytorch.org/whl/cpu` missing `torch/include/torch/csrc/` and `c10/` headers (only ships ATen/) → PyTorch issue #179414 filed
14. cleanup.sh removed torch/include via `find -name "include" -exec rm` → commented out include removal
15. cleanup.sh line 116 explicitly removed torch/include → commented out
16. GHA cache kept serving old cleanup layer → changed cache scope + added CACHEBUST arg
17. `pip`/`uv` removed by cleanup before header restore could run → used `curl` + PyPI JSON API instead
18. IsADirectoryError when extracting headers (ATen/ dir already exists) → skip directory entries and existing dirs in zipfile extraction
19. Inline Python in Dockerfile RUN parsed as Dockerfile instruction → moved to separate `restore_torch_headers.sh` COPY+RUN script

**Solution: torch header restore pipeline:**
- `setup_vllm.sh` installs vLLM + CPU torch (headers present initially)
- `cleanup.sh` runs and may remove headers (cached old version)
- `restore_torch_headers.sh` runs in SEPARATE layer after cleanup
- Checks if `cpp_prefix.h` exists
- If missing: queries PyPI JSON API for matching CUDA wheel URL, downloads via curl, extracts only `include/` files using Python zipfile
- Results: 9,378 header files restored in ~9 seconds

**How to apply:** The GHA cache is the biggest gotcha — any change to cleanup.sh or Dockerfile requires a cache scope bump (increment version in `scope=vllm-cpu-vN-...`) to take effect. Always verify headers exist in the final image before testing inference.
