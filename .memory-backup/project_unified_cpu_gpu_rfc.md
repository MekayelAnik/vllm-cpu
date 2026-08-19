---
name: Unified CPU+GPU wheel RFC (pending)
description: Plan to propose unified CPU+GPU wheel build for vllm — on hold until attribution dispute (issue #38942) is resolved
type: project
---

MekayelAnik plans to propose an RFC for unified CPU+GPU wheel builds in vllm-project/vllm, extending the multi-ISA dispatcher concept to include GPU backends.

**Why:** Natural evolution of the multi-ISA CPU work (dtrifiro/vllm PR #9). No one is currently working on this upstream.

**How to apply:** On hold until attribution issue #38942 is resolved. When ready:
1. Research current GPU build system, backend/plugin architecture, wheel sizes
2. Draft RFC issue with proposed approach (lazy imports, runtime detection, plugin architecture)
3. Reference prior multi-ISA work as proof of concept
