#!/usr/bin/env python3
"""Backport upstream fix for the CPU slot-mapping kernel fallback.

vLLM 0.32.0 changed `_compute_slot_mapping_kernel` in vllm/v1/worker/block_table.py
(dropped the `block_size` and `BLOCKS_PER_KV_BLOCK` arguments) but left the CPU
fallback in vllm/utils/cpu_triton_utils.py with the old signature. The dispatcher
forwards arguments positionally, so every argument after `block_table_stride`
lands in the wrong parameter and the assert sees a Tensor:
    RuntimeError: Boolean value of Tensor with more than one value is ambiguous
Upstream main already carries the fixed fallback; this applies the same change.

Idempotent and version-aware: does nothing when the kernel and fallback already
agree (e.g. 0.31.0 and upstream main), and fails loudly if the layout is unknown.
"""
import pathlib
import re
import sys

utils = pathlib.Path("vllm/utils/cpu_triton_utils.py")
table = pathlib.Path("vllm/v1/worker/block_table.py")
for f in (utils, table):
    if not f.exists():
        print(f"SKIP: {f} not found (layout differs, nothing to patch)")
        sys.exit(0)

src = utils.read_text()
kernel_src = table.read_text()

impl_is_old = "BLOCKS_PER_KV_BLOCK" in src.split("def _compute_slot_mapping_kernel_impl", 1)[-1].split("\ndef ", 1)[0]
kernel_is_old = "BLOCKS_PER_KV_BLOCK" in kernel_src

if not impl_is_old:
    print("OK: cpu_triton_utils slot-mapping fallback already current, no patch needed")
    sys.exit(0)
if kernel_is_old:
    print("OK: kernel still uses BLOCKS_PER_KV_BLOCK, fallback matches, no patch needed")
    sys.exit(0)

NEW = '''def _compute_slot_mapping_kernel_impl(
    num_tokens: int,
    max_num_tokens: int,
    query_start_loc: torch.Tensor,  # [num_reqs + 1], int32
    positions: torch.Tensor,  # [num_tokens], int64
    block_table: torch.Tensor,  # [max_num_reqs, max_num_blocks_per_req], int32
    block_table_stride: int,  # max_num_blocks_per_req
    slot_mapping: torch.Tensor,  # [max_num_tokens], int64
    KV_CACHE_BLOCK_SIZE: int,
    TOTAL_CP_WORLD_SIZE: int = 1,
    TOTAL_CP_RANK: int = 0,
    CP_KV_CACHE_INTERLEAVE_SIZE: int = 1,
    PAD_ID: int = -1,
    BLOCK_SIZE: int = 1024,
) -> None:
    assert TOTAL_CP_WORLD_SIZE == 1, "Context Parallelism is not supported on CPU."
    torch.ops._C.compute_slot_mapping_kernel_impl(
        query_start_loc,
        positions,
        block_table,
        slot_mapping,
        KV_CACHE_BLOCK_SIZE,
    )
'''
pattern = re.compile(
    r"def _compute_slot_mapping_kernel_impl\(.*?"
    r"torch\.ops\._C\.compute_slot_mapping_kernel_impl\(.*?\n    \)\n",
    re.DOTALL,
)
new_src, n = pattern.subn(lambda _m: NEW, src, count=1)
if n != 1:
    print("ERROR: could not locate _compute_slot_mapping_kernel_impl to patch", file=sys.stderr)
    sys.exit(1)
compile(new_src, str(utils), "exec")  # syntax check
utils.write_text(new_src)
print("Patched cpu_triton_utils._compute_slot_mapping_kernel_impl to match current kernel signature")
