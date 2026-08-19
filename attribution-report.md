# Attribution Report: Multi-ISA CPU Dispatcher Contribution

**Prepared by**: Mohammad Mekayel Anik ([@MekayelAnik](https://github.com/MekayelAnik))
**Date**: 2026-04-04
**Regarding**: Unattributed use of prior work in vllm-project/vllm#35466

---

## Summary

My original work on a Python dispatcher for multi-ISA CPU support — contributed to [dtrifiro/vllm PR #9](https://github.com/dtrifiro/vllm/pull/9) in December 2025 — was used without attribution in [vllm-project/vllm PR #35466](https://github.com/vllm-project/vllm/pull/35466), merged on 2026-02-28. A clear lineage exists through an intermediate PR ([#35346](https://github.com/vllm-project/vllm/pull/35346)) that explicitly rebased my commits, was closed, and replaced the next day with a reimplementation that gave no credit.

---

## Timeline of Events

### 1. Original Contribution — December 2025

| Detail | Value |
|--------|-------|
| **Repository** | [dtrifiro/vllm](https://github.com/dtrifiro/vllm) |
| **PR** | [#9 — "fix: Add Python dispatcher for multi-ISA CPU support"](https://github.com/dtrifiro/vllm/pull/9) |
| **Author** | MekayelAnik (MD. MEKAYEL ANIK) |
| **Created** | 2025-12-19 |
| **Merged** | 2025-12-22 (into `cpu-build-dispatcher` branch) |
| **Commits** | 3 commits, all authored by MekayelAnik |

**What the contribution did:**

- Created `vllm/_ops_dispatch.py` — a new Python dispatcher module providing `get_ops()`, `get_utils()`, `has_op()`, and `_detect_cpu_extension()` functions
- Updated **83+ `torch.ops._C.*` call sites** across **23+ files** to use the dispatcher
- Replaced `hasattr(torch.ops._C, ...)` checks with `has_op()` across compilation, distributed, and model executor files

**Problem solved:**

The two CPU extensions (`_C.so` for AVX2/generic and `_C_avx512.so` for AVX512) registered to different `torch.ops` namespaces, causing runtime crashes when code assumed a single namespace. My dispatcher detected which extension was loaded and routed calls to the correct namespace at runtime — enabling multi-ISA CPU support in a single wheel.

### 2. First Upstream Attempt — 2026-02-26

| Detail | Value |
|--------|-------|
| **Repository** | [vllm-project/vllm](https://github.com/vllm-project/vllm) |
| **PR** | [#35346](https://github.com/vllm-project/vllm/pull/35346) (closed, not merged) |
| **Author** | `majian4work` (Ma Jian, Intel) |
| **Created** | 2026-02-26 |
| **Status** | Closed without merging |

**Key evidence:**

- The PR description **explicitly states**: *"Rebase https://github.com/dtrifiro/vllm/tree/cpu-build-dispatcher-cleanup"*
- This PR **directly contains all 3 of my commits** with my authorship preserved
- My file `vllm/_ops_dispatch.py` is included in this PR
- All commits are re-signed as `Signed-off-by: Ma Jian <jian1.ma@intel.com>` but retain my original authorship
- The PR was closed due to build issues flagged by CI/review bots

### 3. Reimplementation Without Attribution — 2026-02-27

| Detail | Value |
|--------|-------|
| **Repository** | [vllm-project/vllm](https://github.com/vllm-project/vllm) |
| **PR** | [#35466 — "[CI/Build] CPU release supports both of AVX2 and AVX512"](https://github.com/vllm-project/vllm/pull/35466) |
| **Author** | `majian4work` (Ma Jian, Intel) |
| **Created** | 2026-02-27 (one day after PR #35346) |
| **Merged** | 2026-02-28 |

**Key facts:**

- Opened **one day** after the first attempt (PR #35346) that contained my commits was closed
- Solves the **exact same problem**: multi-ISA CPU support in a single wheel
- Description is simply: *"A simple version to support multiple ISAs in one wheel"*
- **Zero attribution** to me (MekayelAnik), Daniele Trifiro (dtrifiro), PR #35346, or the `cpu-build-dispatcher` branch
- Commits authored by `jiang1.li` / `Li, Jiang` (Intel) with only `Signed-off-by: jiang1.li <jiang1.li@intel.com>`

---

## Technical Comparison

| Aspect | My Approach (dtrifiro/vllm PR #9) | Merged Upstream (PR #35466) |
|--------|-----------------------------------|----------------------------|
| **Problem solved** | Multi-ISA CPU support (AVX2 + AVX512 in one wheel) | Identical |
| **Dispatch mechanism** | Python-level dispatcher (`_ops_dispatch.py`) routing `torch.ops._C.*` calls to correct namespace at runtime | C++ level: `#define TORCH_EXTENSION_NAME _C` forces both extensions to register under `torch.ops._C`, then Python `import_kernels()` loads the right `.so` |
| **ISA detection** | Python `_detect_cpu_extension()` checking `hasattr(torch.ops, '_C_avx512')` | `torch.cpu._is_avx512_supported()` in `CpuPlatform.import_kernels()` |
| **Python call site changes** | 83+ call sites modified to use `get_ops().xxx` | No Python call site changes needed |
| **Files modified** | 29 files | 6 files |
| **Scope** | Comprehensive Python-side refactor | Build-system-focused fix |

While the final implementation uses a different mechanism (C++ macro vs. Python dispatcher), the underlying **problem identification**, the **concept of runtime ISA detection**, and the **goal of multi-ISA CPU support in a single wheel** are directly derived from the work on the `cpu-build-dispatcher` branch where I was a key contributor.

---

## Evidence of Lineage

The chain of evidence is unambiguous:

1. **2025-12-19**: I create the multi-ISA dispatcher solution on dtrifiro/vllm
2. **2025-12-22**: My PR #9 is merged into dtrifiro's `cpu-build-dispatcher` branch
3. **2026-02-26**: `majian4work` opens upstream PR #35346, explicitly rebasing dtrifiro's `cpu-build-dispatcher` branch — **which includes my 3 commits**
4. **2026-02-27**: PR #35346 is closed; `majian4work` opens PR #35466 the **next day** — a "simple version" solving the same problem with **no attribution whatsoever**
5. **2026-02-28**: PR #35466 is merged into vllm-project/vllm

The one-day turnaround between closing PR #35346 (which contained my work) and opening PR #35466 (which reimplemented it) strongly demonstrates that PR #35466 was directly informed by my prior work.

---

## Request

I respectfully request that the vLLM project:

1. **Acknowledge** that the multi-ISA CPU dispatcher work in PR #35466 was informed by prior work on the `cpu-build-dispatcher` branch of dtrifiro/vllm, to which I (MekayelAnik) was a contributor
2. **Add attribution** in the form of a comment on PR #35466, a mention in release notes, or a `Co-authored-by` acknowledgment
3. **Grant contributor status** — my work directly contributed to solving this problem and I should be recognized as a contributor to the vLLM project. My commits exist in PR #35346 with my authorship intact, proving my contribution. I request to be added to the project's contributors list
4. **Establish clear guidelines** for attributing prior art when reimplementing community contributions

---

## Appendix: Verifiable Links

- My original PR: https://github.com/dtrifiro/vllm/pull/9
- PR containing my commits (closed): https://github.com/vllm-project/vllm/pull/35346
- Merged PR without attribution: https://github.com/vllm-project/vllm/pull/35466
- dtrifiro/vllm `cpu-build-dispatcher` branch: https://github.com/dtrifiro/vllm/tree/cpu-build-dispatcher
- My GitHub profile: https://github.com/MekayelAnik
