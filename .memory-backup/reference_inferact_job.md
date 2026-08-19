---
name: Inferact job opportunity and skill growth plan
description: Inferact (youkaichao's company) MTS role — skill gaps, growth path, and timing considerations
type: reference
---

## Inferact — Member of Technical Staff, Exceptional Generalist (Remote)
- URL: https://jobs.ashbyhq.com/Inferact/f0d2619d-28e0-4b25-8d30-3ac555071abb
- Company: Inferact — founded by vLLM creators/core maintainers (youkaichao is Co-Founder & Chief Scientist)
- Role: Generalist across vLLM stack — GPU kernels, distributed systems, model architectures, cloud orchestration
- Location: Fully remote, worldwide. Timezone-flexible with Pacific Time overlap.
- Compensation: Salary + equity, adjusted to local market conditions.

## Skills match assessment
**Strong match:**
- Python + PyTorch + vLLM inference systems
- Contributions to vLLM (PR #39085, CPU ecosystem)
- Intel accelerator platforms (ISA variants — AVX512, VNNI, BF16, AMX)
- Docker, CI/CD, container orchestration
- Autonomous, self-directed work style

**Gaps to fill:**
- CUDA kernels / GPU programming
- Distributed systems in Rust/Go/C++
- Kubernetes at scale
- Transformer internals / KV-cache memory management

## Skill growth roadmap
1. **CUDA / GPU Programming** (most critical gap, 2-3 weeks)
   - NVIDIA free course: "Fundamentals of Accelerated Computing with CUDA"
   - Write simple kernels: matrix multiply, vector add, reduction
   - Read vLLM kernel code in `csrc/`
   - Practice on Google Colab (free GPU)

2. **Distributed Systems** (1-2 months)
   - MIT 6.824 lectures + labs (free on YouTube)
   - Build something with Ray (vLLM uses Ray)
   - Read vLLM's `vllm/distributed/` code

3. **Transformer Internals / KV-Cache** (1-2 weeks)
   - Andrej Karpathy's "Let's build GPT from scratch" (YouTube)
   - Read vLLM attention backends and KV-cache management
   - Understand PagedAttention (vLLM's core innovation)

4. **C++ Systems Programming** (ongoing)
   - Read and modify vLLM's C++ extensions in `csrc/`
   - Already builds these — go one layer deeper

5. **Capstone: Submit a real optimization PR to vLLM** (2-4 weeks)
   - Not a comment fix — an actual CPU/kernel optimization
   - Worth more than any course certificate on a resume

## Timing consideration
- Do NOT apply now — active attribution dispute with youkaichao (tagged on issue #38942)
- Resolve dispute first, then apply
- If resolved well, the story becomes an asset: "built CPU ecosystem independently, want to do it professionally"
- Save the link and revisit after dispute resolution

## Salary expectations (estimated, USD/year)
- US (SF Bay Area): $180k-$300k + equity
- US (other): $150k-$250k + equity
- Europe: $100k-$180k + equity
- South Asia (Bangladesh): $40k-$80k + equity
- Startup equity could be significant given vLLM's growth trajectory

## Equity and negotiation notes
- Equity is typically **same or similar** across locations — based on role/impact, not geography
- Location adjustment usually only applies to cash salary
- Equity is where the real value is if Inferact succeeds (vLLM is growing fast)
- Negotiate: accept lower base salary but push for **higher equity**
- Or argue "global rate" based on role complexity — rare vLLM CPU expertise is location-independent
- Always ask before accepting: vesting schedule, strike price, latest valuation
- Get equity offer in writing
- Reminder: startup equity = $0 until liquidity event (acquisition/IPO). It's a bet.
