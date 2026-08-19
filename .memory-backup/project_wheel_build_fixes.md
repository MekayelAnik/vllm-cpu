---
name: Wheel build pipeline fixes
description: All issues found and fixed during vllm-cpu wheel build pipeline implementation (v0.17.0+)
type: project
---

Issues fixed across ~15+ build iterations for the unified CPU wheel pipeline:

**Build environment:**
1. Python 3.14 auto-selected on aarch64 (no cmake wheels) → pin Python 3.12
2. CUDA torch installed instead of CPU → use `--index-url` (not `--extra-index-url`)
3. Build isolation reinstalls CUDA torch → `--no-isolation` flag
4. `uv --system` installs to wrong Python → switch to `pip3` with explicit paths

**Version/naming:**
5. setuptools-scm generates `0.17.1.dev0+g<hash>.cpu` → `SETUPTOOLS_SCM_PRETEND_VERSION`
6. `+cpu` suffix in wheel filename → sed strip in rename step
7. `+cpu` in wheel METADATA (PyPI rejects local versions) → comment out `version += f"{sep}cpu"` in setup.py via printf temp script
8. ABI tag `cp312-cp312` not `cp38-abi3` → sed rename
9. Platform tag dots (`manylinux_2_28.x86.64`) → simplified sed with `manylinux_2_28_\2`

**YAML/GitHub Actions:**
10. YAML parse error from multi-line Python in run block → rewrite as one-liners or printf to temp file
11. GitHub workflow_dispatch not recognized → rename file to force re-registration
12. Single quotes in docker `bash -exc` block → avoid single quotes, use printf temp scripts
13. `$PLATFORM` unbound in container → add `-e "PLATFORM=${PLATFORM}"` to docker run

**Smoke test:**
14. `device='cpu'` parameter removed in v0.19.0 → try/except TypeError fallback
15. vLLM can't detect CPU platform (`version("vllm")` fails for `vllm-cpu` package) → patch `platforms/__init__.py` + create vllm dist-info shim
16. `VLLM_TARGET_DEVICE=cpu` not propagating → set inline on every python3 call + os.environ
17. SmolLM2-135M-Instruct generates empty text → switch to `facebook/opt-125m` with temperature=0.8
18. HF cache lock conflicts on shared ARM runners → per-platform `HF_HOME`
19. libtcmalloc required by v0.18.0 → install + preload in smoke test
20. libiomp5 required on x86_64 → find from PyTorch bundle, add to LD_PRELOAD (x86 only)

**PyPI publishing:**
21. PEP 639 `license-expression`/`license-file` metadata rejected by twine 6.x → use `pypa/gh-action-pypi-publish@v1.13.0`

**aarch64 no-bf16 variant:**
22. `_no_bf16` in wheel filename breaks pip → keep pip-compatible name, differentiate by artifact
23. Same ARM runner cache conflict → per-platform HF_HOME

**How to apply:** Reference when debugging future wheel build failures. The quoting issues inside docker `bash -exc '...'` blocks are the most recurring problem — always use printf to temp file for Python code.
