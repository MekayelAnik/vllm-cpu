# Why torchvision and torchaudio Are Required

## Question

Do vLLM CPU wheels need torchvision and torchaudio?

## Answer

**YES - Both are required** for full vLLM functionality.

## Verification from vLLM Source

### From requirements/cpu.txt

```txt
# required for the image processor of phi3v, this must be updated alongside torch
torchvision; platform_machine != "ppc64le" and platform_machine != "s390x"

# required for the image processor of minicpm-o-2_6, this must be updated alongside torch
torchaudio; platform_machine != "ppc64le" and platform_machine != "s390x"
```

### Models That Use torchvision

Based on vLLM source code analysis:

1. **deepseek_vl2** - `import torchvision.transforms as T`
2. **deepseek_ocr** - `import torchvision.transforms as T`
3. **step3_vl** - `from torchvision import transforms`
4. **skyworkr1v** - `import torchvision.transforms as T`
5. **qwen_vl** - `from torchvision import transforms`
6. **nemotron_vl** - `import torchvision.transforms as T`
7. **nano_nemotron_vl** - `import torchvision.transforms as T`
8. **internvl** - `import torchvision.transforms as T`
9. **glm4v** - `from torchvision import transforms`
10. **phi3v** (mentioned in requirements)

### Models That Use torchaudio

1. **midashenglm** - `import torchaudio.functional as F`
2. **minicpm-o-2_6** (mentioned in requirements)

## What Happens Without Them?

### Without torchvision

```python
# User tries to load a vision-language model
from vllm import LLM

llm = LLM(model="Qwen/Qwen-VL-Chat")
# Error: ModuleNotFoundError: No module named 'torchvision'
```

### Without torchaudio

```python
# User tries to load an audio model
from vllm import LLM

llm = LLM(model="openbmb/MiniCPM-o-2_6")
# Error: ModuleNotFoundError: No module named 'torchaudio'
```

## Installation Size Comparison

### Option 1: Text-Only (Not Supported)

```bash
pip install torch --index-url https://download.pytorch.org/whl/cpu
# Size: ~200MB
# Problem: Vision and audio models won't work
```

### Option 2: Full Support (Correct)

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
# Size: ~210MB (torch 200MB + torchvision 7MB + torchaudio 3MB)
# Benefit: All models work (text, vision, audio)
```

### Option 3: CUDA Version (Wrong for vllm-cpu)

```bash
pip install torch torchvision torchaudio
# Size: ~2.5GB (torch 2.3GB + torchvision 12MB + torchaudio 8MB)
# Problem: Unnecessary CUDA dependencies
```

## Size Impact

| Component | CPU Version | CUDA Version |
|-----------|-------------|--------------|
| torch | ~200MB | ~2.3GB |
| torchvision | ~7MB | ~12MB |
| torchaudio | ~3MB | ~8MB |
| **Total** | **~210MB** | **~2.5GB** |

**Overhead from torchvision/torchaudio**: Only +10MB (5% increase)

**Benefits**: Support for all model types (text, vision, audio)

## Conclusion

### Keep Both ✅

**Reasons**:
1. ✅ **Required by vLLM**: Explicitly listed in requirements/cpu.txt
2. ✅ **Minimal overhead**: Only +10MB (5% increase)
3. ✅ **Full functionality**: Supports all model types
4. ✅ **Prevents errors**: Vision/audio models work out of the box
5. ✅ **Official requirements**: Matches vLLM's own CPU requirements

### Don't Remove ❌

**Consequences of removal**:
- ❌ Vision-language models fail (phi3v, qwen-vl, internvl, etc.)
- ❌ Audio models fail (minicpm-o-2_6, etc.)
- ❌ Confusing error messages for users
- ❌ Doesn't match vLLM's official requirements
- ❌ Minimal size savings (~10MB) vs broken functionality

## Updated Installation Instructions

### For End Users

```bash
# Complete installation with all model support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
pip install vllm-cpu
```

### For Build Process

```bash
# Build script automatically installs all three
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

### In Wheel Metadata

```toml
# vLLM CPU wheels require PyTorch CPU-only version with vision and audio support
# Users should install PyTorch before installing this package:
# pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
#
# Note: torchvision is required for vision-language models (phi3v, minicpm, qwen-vl, etc.)
#       torchaudio is required for audio models (minicpm-o-2_6, etc.)
```

## Model Type Support Matrix

| Model Type | Requires torch | Requires torchvision | Requires torchaudio |
|------------|---------------|---------------------|---------------------|
| Text (LLaMA, GPT, etc.) | ✅ | ❌ | ❌ |
| Vision-Language (phi3v, qwen-vl) | ✅ | ✅ | ❌ |
| Audio (minicpm-o-2_6) | ✅ | ❌ | ✅ |
| Multimodal (all types) | ✅ | ✅ | ✅ |

**Since vLLM supports all model types, we need all three packages.**

## FAQ

### Q: Can I install vLLM CPU without torchvision/torchaudio?

**A**: Technically yes, but vision and audio models won't work. Not recommended.

### Q: How much space do torchvision and torchaudio add?

**A**: Only ~10MB combined (5% overhead on top of PyTorch's 200MB).

### Q: What if I only use text models?

**A**: Still recommended to install both for:
- Future-proofing (if you want to try vision/audio models later)
- Avoiding confusing errors
- Matching vLLM's official requirements

### Q: Does the CUDA version have the same requirement?

**A**: Yes, but the packages are larger:
- CPU: torch (200MB) + torchvision (7MB) + torchaudio (3MB) = 210MB
- CUDA: torch (2.3GB) + torchvision (12MB) + torchaudio (8MB) = 2.5GB

## Summary

✅ **Keep torchvision and torchaudio**
- Required by vLLM for vision and audio models
- Only +10MB overhead (5%)
- Prevents runtime errors
- Matches official requirements

❌ **Don't remove them**
- Breaks vision-language models
- Breaks audio models
- Minimal size savings
- Creates confusing user experience

**Final Installation Command**:
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && pip install vllm-cpu
```

---

**Date**: 2025-11-21
**Decision**: Keep both torchvision and torchaudio
**Status**: ✅ Confirmed Required
