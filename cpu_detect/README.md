<!-- markdownlint-disable MD001 MD041 -->
<h1 align="center">vllm-cpu-detect</h1>

<p align="center">
  <em>CPU detection tool for vLLM CPU builds. Automatically detects your CPU's instruction set extensions and recommends the optimal vLLM CPU package.</em>
</p>

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
  <a href="https://pypi.org/project/vllm-cpu-detect/">
    <img src="https://img.shields.io/pypi/v/vllm-cpu-detect?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=3775a9" alt="PyPI Version">
  </a>
  <a href="https://pypi.org/project/vllm-cpu-detect/">
    <img src="https://img.shields.io/pypi/dm/vllm-cpu-detect?style=for-the-badge&logo=pypi&logoColor=white&labelColor=2b3137&color=9c27b0" alt="PyPI Downloads">
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
</p>

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating/supporting my open-source projects.** If you found value in this project, you can buy me a coffee to keep me up all the sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 40px !important;width: 145px !important;" >
</a>

</div>

---

## Installation

```bash
pip install vllm-cpu-detect
```

## Usage

```bash
vllm-cpu-detect
```

## Example Output

```
======================================================================
vLLM CPU Package Detector
======================================================================

System:       Linux
Architecture: x86_64
CPU Model:    Intel(R) Xeon(R) Platinum 8488C

Detected CPU Features:
----------------------------------------------------------------------
  ✓ AVX512F             Supported
  ✓ AVX512_VNNI         Supported
  ✓ AVX512_BF16         Supported
  ✓ AMX_BF16            Supported
  ✓ AMX_TILE            Supported
  ✓ AMX_INT8            Supported

Recommended Package:
----------------------------------------------------------------------
  vllm-cpu-amxbf16

Installation Command:
----------------------------------------------------------------------
  pip install vllm-cpu-amxbf16

All Available Packages:
----------------------------------------------------------------------
     vllm-cpu                  - Base package (no AVX512, supports ARM64 & x86_64)
     vllm-cpu-avx512           - AVX512 optimized (Intel Skylake-X and newer)
     vllm-cpu-avx512vnni       - AVX512 + VNNI (Intel Cascade Lake and newer)
     vllm-cpu-avx512bf16       - AVX512 + VNNI + BF16 (Intel Cooper Lake and newer)
  👉 vllm-cpu-amxbf16          - AVX512 + VNNI + BF16 + AMX (Intel Sapphire Rapids and newer)

======================================================================
```

## Features Detected

- **AVX512F**: Advanced Vector Extensions 512 (Foundation)
- **AVX512_VNNI**: Vector Neural Network Instructions
- **AVX512_BF16**: BFloat16 hardware support
- **AMX_BF16**: Advanced Matrix Extensions for BFloat16
- **AMX_TILE**: AMX tile register support
- **AMX_INT8**: AMX INT8 operations

## Supported Platforms

- Linux (x86_64, aarch64)
- macOS (limited detection)
- Windows (limited detection)

---

<div align="center">

## Buy Me a Coffee

**Your support encourages me to keep creating/supporting my open-source projects.** If you found value in this project, you can buy me a coffee to keep me up all the sleepless nights.

<a href="https://07mekayel07.gumroad.com/coffee" target="_blank">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 40px !important;width: 145px !important;" >
</a>

</div>

---

## License

Apache License 2.0
