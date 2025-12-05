<!-- markdownlint-disable MD001 MD041 -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/vllm-project/vllm/main/docs/assets/logos/vllm-logo-text-dark.png">
    <img alt="vLLM" src="https://raw.githubusercontent.com/vllm-project/vllm/main/docs/assets/logos/vllm-logo-text-light.png" width=55%>
  </picture>
</p>

<h3 align="center">
Easy, fast, and cheap LLM serving for everyone
</h3>

<p align="center">
  <a href="https://github.com/MekayelAnik/vllm-cpu/stargazers">
    <img src="https://img.shields.io/github/stars/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=f0c14b" alt="GitHub Stars">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/network/members">
    <img src="https://img.shields.io/github/forks/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=6cc644" alt="GitHub Forks">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/issues">
    <img src="https://img.shields.io/github/issues/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=d73a49" alt="GitHub Issues">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/pulls">
    <img src="https://img.shields.io/github/issues-pr/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=2188ff" alt="GitHub PRs">
  </a>
</p>

<p align="center">
  <a href="https://pypi.org/project/vllm-cpu-avx512bf16/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu-avx512bf16?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9" alt="PyPI Version">
  </a>
  <a href="https://pypi.org/project/vllm-cpu-avx512bf16/">
    <img src="https://img.shields.io/pypi/dm/vllm-cpu-avx512bf16?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=9c27b0" alt="PyPI Downloads">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/MekayelAnik/vllm-cpu?style=for-the-badge&logo=gnu&logoColor=white&labelColor=2b3137&color=a32d2a" alt="License">
  </a>
</p>

<p align="center">
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/pulls/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=0db7ed" alt="Docker Pulls">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/stars/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=f0c14b" alt="Docker Stars">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/v/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=6cc644&label=version" alt="Docker Version">
  </a>
  <a href="https://hub.docker.com/r/mekayelanik/vllm-cpu">
    <img src="https://img.shields.io/docker/image-size/mekayelanik/vllm-cpu?style=for-the-badge&logo=docker&logoColor=white&labelColor=2b3137&color=9c27b0" alt="Docker Image Size">
  </a>
</p>

<p align="center">
  <a href="https://github.com/MekayelAnik/vllm-cpu/commits/main">
    <img src="https://img.shields.io/github/last-commit/MekayelAnik/vllm-cpu?style=for-the-badge&logo=git&logoColor=white&labelColor=2b3137&color=ff6f00" alt="Last Commit">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=00bcd4" alt="Contributors">
  </a>
  <a href="https://github.com/MekayelAnik/vllm-cpu">
    <img src="https://img.shields.io/github/repo-size/MekayelAnik/vllm-cpu?style=for-the-badge&logo=github&logoColor=white&labelColor=2b3137&color=607d8b" alt="Repo Size">
  </a>
</p>

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating/supporting my open-source projects.** If you found value in this project, you can buy me a coffee to keep me up all the sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="217" height="60">
</a>

</div>

---

## About

vLLM is a fast and easy-to-use library for LLM inference and serving. <b>This PyPl package has only supports AVX512+VNNI+AVX512BF16</b>. No support for AMXBF16</b> is available in this package. CPU inference will have the above available instruction set accelerations.

Originally developed in the [Sky Computing Lab](https://sky.cs.berkeley.edu) at UC Berkeley, vLLM has evolved into a community-driven project with contributions from both academia and industry.

vLLM is fast with:

- State-of-the-art serving throughput
- Efficient management of attention key and value memory with [**PagedAttention**](https://blog.vllm.ai/2023/06/20/vllm.html)
- Continuous batching of incoming requests
- Fast model execution with <b>AVX512+VNNI+AVX512BF16 on supported CPUs</b> Use this package <b>ONLY IF</b> your CPU have <b>avx512bf16</b> or newer instruction sets.
- Quantizations: [GPTQ](https://arxiv.org/abs/2210.17323), [AWQ](https://arxiv.org/abs/2306.00978), [AutoRound](https://arxiv.org/abs/2309.05516), INT4, INT8, and FP8
- Optimized CPU kernels, including integration with FlashAttention and FlashInfer
- Speculative decoding
- Chunked prefill

vLLM is flexible and easy to use with:

- Seamless integration with popular Hugging Face models
- High-throughput serving with various decoding algorithms, including *parallel sampling*, *beam search*, and more
- Tensor, pipeline, data and expert parallelism support for distributed inference
- Streaming outputs
- OpenAI-compatible API server
- Support for x86_64, PowerPC CPUs, Arm CPUs and Applie Scilicon (CPU inference). <b>This package does not support any GPU inference.</b> For GPU inference support use the official [vLLM PypI](https://pypi.org/project/vllm/)
- Prefix caching support
- Multi-LoRA support

vLLM seamlessly supports most popular open-source models on HuggingFace, including:

- Transformer-like LLMs (e.g., Llama)
- Mixture-of-Expert LLMs (e.g., Mixtral, Deepseek-V2 and V3)
- Embedding Models (e.g., E5-Mistral)
- Multi-modal LLMs (e.g., LLaVA)

Find the full list of supported models [here](https://docs.vllm.ai/en/latest/models/supported_models.html).

## Important Notes

- Install this package on Linux envirenment only. For Windows you will have to use WSL2 or later
- This package has a Container.io (Docker/Podman etc.) compatible image in [Docker Hub](https://hub.docker.com/r/mekayelanik/vllm-cpu)
- [Apache Licence of main vLLM project](https://raw.githubusercontent.com/vllm-project/vllm/refs/heads/main/LICENSE)
- [GPL License of this CPU specific vLLM package](https://raw.githubusercontent.com/MekayelAnik/vllm-cpu/refs/heads/main/LICENSE)
- **For versions 0.8.5–0.12.0, use `.post2` releases** (e.g., `pip install vllm-cpu-avx512bf16==0.12.0.post2`) — includes critical CPU platform detection fix

## Platform Detection Fix (versions 0.8.5 - 0.12.0)

If you encounter `RuntimeError: Failed to infer device type` or see `UnspecifiedPlatform` warnings with versions 0.8.5 to 0.12.0, run this one-time fix after installation:

```python
import os, sys, importlib.metadata as m
v = next((d.metadata['Version'] for d in m.distributions() if d.metadata['Name'].startswith('vllm-cpu')), None)
if v:
    p = next((p for p in sys.path if 'site-packages' in p and os.path.isdir(p)), None)
    if p:
        d = os.path.join(p, 'vllm-0.0.0.dist-info'); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, 'METADATA'), 'w').write(f'Metadata-Version: 2.1\nName: vllm\nVersion: {v}+cpu\n')
        print(f'Fixed: vllm version set to {v}+cpu')
```

This creates a package alias so vLLM detects the CPU platform correctly. Only needed once per environment. Versions after 0.12.0 include this fix automatically.

## Getting Started

Install vLLM with `pip` or `uv`

```bash
mkdir -p /path/to/vllm
cd /path/to/vllm
uv venv
uv pip install torch==2.8.0 torchvision --index-url https://download.pytorch.org/whl/cpu
uv pip install vllm-cpu-avx512bf16
```
Install `uv` on Linux environment using CURL:
```
curl -LsSf https://astral.sh/uv/install.sh | sh
```
or using WGET
```
wget -qO- https://astral.sh/uv/install.sh | sh
```
if you wanna install a specific version of `uv`
```
curl -LsSf https://astral.sh/uv/0.9.11/install.sh | sh
```

## vllm-cpu
This CPU specific vLLM has **5 optimized wheel packages** from the upstream vLLM source code:

| Package | Optimizations | Target CPUs |
|---------|--------------|-------------|
| [`vllm-cpu`](https://pypi.org/project/vllm-cpu/) | Baseline (no AVX512) | All x86_64 and ARM64 CPUs |
| [`vllm-cpu-avx512`](https://pypi.org/project/vllm-cpu-avx512/) | AVX512 | Intel Skylake-X and newer |
| [`vllm-cpu-avx512vnni`](https://pypi.org/project/vllm-cpu-avx512vnni/) | AVX512 + VNNI | Intel Cascade Lake and newer |
| [`vllm-cpu-avx512bf16`](https://pypi.org/project/vllm-cpu-avx512bf16/) | AVX512 + VNNI + BF16 | Intel Cooper Lake and newer |
| [`vllm-cpu-amxbf16`](https://pypi.org/project/vllm-cpu-amxbf16/) | AVX512 + VNNI + BF16 + AMX | Intel Sapphire Rapids (4th gen Xeon+) |

Each package is compiled with specific CPU instruction set flags for optimal inference performance.


## Check available CPU instruction sets
```
lscpu | grep -i flags
```
## Example list of CPUs with their supported instruction sets
 | CPU Architecture (Intel/AMD) | AVX2 | AVX-512 F (Base) | VNNI (INT8) | BF16 (BFloat16) (via AVX-512) | AMX-BF16 (via Tile Unit) |
|---------|--------------|:-------------:|:-------------:|:-------------:|:-------------:|
| Intel 4th Gen / AMD Ryzen Zen2 & Newer | Yes | No	| No | No | No |
| Intel Skylake-SP / Skylake-X / AMD Zen 4 & Newer | Yes | Yes	| No	| No	| No |
| Intel Cooper Lake (3rd Gen Xeon) / AMD Zen 4 (EPYC) / Ryzen Zen5 & Newer | Yes | Yes | Yes | Yes | No |
|Intel Sapphire Rapids (4th Gen Xeon) & Newer	| Yes	| Yes	| Yes	| Yes | Yes |

<b>***Currently no AMD CPU support AMXBF16. AMD expected to include AMXBF16 support from AMD Zen 7 CPUs</b>

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating/supporting my open-source projects.** If you found value in this project, you can buy me a coffee to keep me up all the sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="217" height="60">
</a>

</div>

---

- [vLLM documentation](https://docs.vllm.ai/en/latest/) to learn more.
- [GitHub Repo for this package](https://github.com/MekayelAnik/vllm-cpu)
- [DockerHub](https://hub.docker.com/r/mekayelanik/vllm-cpu)
- [List of Supported Models](https://docs.vllm.ai/en/latest/models/supported_models.html)