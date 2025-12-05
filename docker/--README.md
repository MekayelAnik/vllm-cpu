# vLLM CPU Docker Images

Pre-built Docker images for running vLLM with CPU-optimized inference.

These images install pre-built wheels from PyPI (with fallback to GitHub releases), **not** built from source. This means fast image builds and guaranteed compatibility.

**Optimized for size:** Uses `debian:bookworm-slim` + `uv` instead of Python base images for smaller footprint.

## Quick Start

```bash
# Pull and run with default model
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m

# Test the API
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "facebook/opt-125m", "prompt": "Hello, ", "max_tokens": 50}'
```

## Available Images

All images are **multi-arch manifests** - Docker automatically pulls the correct architecture for your system.

| Variant | Tag Pattern | Platforms | Best For |
|---------|-------------|-----------|----------|
| `noavx512` | `noavx512-<version>` | amd64, arm64 | Any CPU, ARM processors (Graviton, Apple Silicon) |
| `avx512` | `avx512-<version>` | amd64 | Intel Skylake-X+ |
| `avx512vnni` | `avx512vnni-<version>` | amd64 | Intel Cascade Lake+ |
| `avx512bf16` | `avx512bf16-<version>` | amd64 | Intel Cooper Lake+ |
| `amxbf16` | `amxbf16-<version>` | amd64 | Intel Sapphire Rapids+ |

> **Multi-arch support:** The `noavx512` variant contains both amd64 and arm64 images under the same tag. Docker automatically selects the right one for your platform.

### Registries

Images are published to both:
- **Docker Hub**: `mekayelanik/vllm-cpu:<tag>`
- **GitHub Container Registry**: `ghcr.io/mekayelanik/vllm-cpu:<tag>`

## Environment Variables

All vLLM runtime environment variables can be configured. Reference: https://docs.vllm.ai/en/latest/configuration/env_vars/

### CPU Performance Settings (Most Important)

| Variable | Default | Description |
|----------|---------|-------------|
| `OMP_NUM_THREADS` | auto | Number of OpenMP threads (auto-detected if empty) |
| `MKL_NUM_THREADS` | auto | Intel MKL threads |
| `VLLM_CPU_KVCACHE_SPACE` | 4 | CPU KV cache space in GiB |
| `VLLM_CPU_OMP_THREADS_BIND` | auto | CPU core binding (e.g., "0-15", "0,2,4") |
| `VLLM_CPU_NUM_OF_RESERVED_CPU` | 0 | CPU cores not used by OMP |
| `VLLM_CPU_SGL_KERNEL` | 0 | Use SGL kernels for small batch |

### API Server Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_HOST` | 0.0.0.0 | Server bind address |
| `VLLM_PORT` | 8000 | Server port |
| `VLLM_API_KEY` | (empty) | API key for authentication |
| `VLLM_HTTP_TIMEOUT_KEEP_ALIVE` | 5 | HTTP keep-alive timeout (seconds) |
| `VLLM_KEEP_ALIVE_ON_ENGINE_DEATH` | 0 | Keep server alive if engine crashes |
| `VLLM_SERVER_DEV_MODE` | 0 | Enable development/debug endpoints |

### Logging Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_LOGGING_LEVEL` | INFO | Log level: DEBUG, INFO, WARNING, ERROR |
| `VLLM_CONFIGURE_LOGGING` | 1 | Enable vLLM logging configuration |
| `VLLM_LOGGING_CONFIG_PATH` | (empty) | Custom logging config file |
| `VLLM_LOG_STATS_INTERVAL` | 10 | Stats logging interval (seconds) |
| `VLLM_LOGGING_COLOR` | auto | Colored logs: auto, 1, 0 |

### Model Loading Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `HF_TOKEN` | (empty) | HuggingFace token for gated models |
| `HF_HOME` | /root/.cache/huggingface | HuggingFace cache directory |
| `VLLM_USE_MODELSCOPE` | false | Use ModelScope instead of HuggingFace |
| `VLLM_ALLOW_LONG_MAX_MODEL_LEN` | 0 | Allow longer sequences than model config |

### Cache Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_CACHE_ROOT` | /root/.cache/vllm | vLLM cache directory |
| `VLLM_CONFIG_ROOT` | /root/.config/vllm | vLLM config directory |
| `VLLM_ASSETS_CACHE` | /root/.cache/vllm/assets | Assets cache directory |

### Memory Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `MALLOC_TRIM_THRESHOLD_` | 100000 | Memory allocator tuning |
| `VLLM_MM_INPUT_CACHE_GIB` | 4 | Multimodal input cache (GiB) |

### Multimodal Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_IMAGE_FETCH_TIMEOUT` | 5 | Image fetch timeout (seconds) |
| `VLLM_VIDEO_FETCH_TIMEOUT` | 30 | Video fetch timeout (seconds) |
| `VLLM_AUDIO_FETCH_TIMEOUT` | 10 | Audio fetch timeout (seconds) |
| `VLLM_MAX_AUDIO_CLIP_FILESIZE_MB` | 25 | Max audio file size (MB) |
| `VLLM_MEDIA_LOADING_THREAD_COUNT` | 8 | Media loading threads |

### LoRA Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_ALLOW_RUNTIME_LORA_UPDATING` | 0 | Allow runtime LoRA loading |
| `VLLM_LORA_RESOLVER_CACHE_DIR` | (empty) | LoRA adapter cache directory |

### Distributed/Multi-Process Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_WORKER_MULTIPROC_METHOD` | fork | Multiprocessing: fork or spawn |
| `VLLM_ENABLE_V1_MULTIPROCESSING` | 1 | Enable V1 multiprocessing |
| `VLLM_RPC_TIMEOUT` | 10000 | RPC timeout (milliseconds) |
| `LOCAL_RANK` | 0 | Local rank for distributed |

### Engine Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_ENGINE_ITERATION_TIMEOUT_S` | 60 | Engine iteration timeout (seconds) |
| `VLLM_SLEEP_WHEN_IDLE` | 0 | Sleep when idle (saves CPU) |
| `VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS` | 300 | Model execution timeout |

### Tool/Function Calling

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_TOOL_PARSE_REGEX_TIMEOUT_SECONDS` | 1 | Tool parsing regex timeout |
| `VLLM_TOOL_JSON_ERROR_AUTOMATIC_RETRY` | 0 | Auto retry on JSON parse failure |
| `VLLM_XGRAMMAR_CACHE_MB` | 512 | XGrammar cache size (MB) |

### Usage Statistics

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_NO_USAGE_STATS` | 0 | Disable usage statistics |
| `VLLM_DO_NOT_TRACK` | 0 | Do not track flag |

### S3 Storage (for tensorizer)

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_ACCESS_KEY_ID` | (empty) | S3 access key |
| `S3_SECRET_ACCESS_KEY` | (empty) | S3 secret key |
| `S3_ENDPOINT_URL` | (empty) | S3 endpoint URL |

### Debugging

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_TRACE_FUNCTION` | 0 | Trace function calls |
| `VLLM_DEBUG_DUMP_PATH` | (empty) | Debug dump path |
| `VLLM_COMPUTE_NANS_IN_LOGITS` | 0 | Check for NaN in logits |
| `VLLM_DEBUG_LOG_API_SERVER_RESPONSE` | false | Log API responses |

## Usage Examples

### Basic Usage

```bash
# Run with default settings
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m
```

### Optimized CPU Performance

```bash
# Bind to specific CPU cores for better performance
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e OMP_NUM_THREADS=16 \
  -e MKL_NUM_THREADS=16 \
  -e VLLM_CPU_OMP_THREADS_BIND="0-15" \
  -e VLLM_CPU_KVCACHE_SPACE=8 \
  mekayelanik/vllm-cpu:avx512bf16-latest \
  --model facebook/opt-1.3b
```

### With API Key Authentication

```bash
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e VLLM_API_KEY="your-secret-api-key" \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m
```

### Custom Host and Port

```bash
docker run -p 9000:9000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e VLLM_HOST="0.0.0.0" \
  -e VLLM_PORT="9000" \
  -e VLLM_API_KEY="my-api-key" \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m
```

### Debug Mode

```bash
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e VLLM_LOGGING_LEVEL=DEBUG \
  -e VLLM_LOG_STATS_INTERVAL=5 \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m
```

### Using Gated Models (Llama, etc.)

```bash
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=hf_your_token_here \
  mekayelanik/vllm-cpu:avx512bf16-latest \
  --model meta-llama/Llama-2-7b-chat-hf
```

### Disable Telemetry

```bash
docker run -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e VLLM_NO_USAGE_STATS=1 \
  -e VLLM_DO_NOT_TRACK=1 \
  mekayelanik/vllm-cpu:noavx512-latest \
  --model facebook/opt-125m
```

### Using Docker Compose

```bash
# Start with defaults
docker compose up -d

# Start with custom model and variant
MODEL_NAME=mistralai/Mistral-7B-v0.1 VLLM_VARIANT=avx512bf16 docker compose up -d

# View logs
docker compose logs -f

# Stop
docker compose down
```

### Production Configuration

```bash
docker run -d \
  --name vllm-server \
  --restart unless-stopped \
  -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -v /path/to/models:/models:ro \
  -e OMP_NUM_THREADS=32 \
  -e VLLM_CPU_KVCACHE_SPACE=16 \
  -e VLLM_API_KEY="${VLLM_API_KEY}" \
  -e VLLM_LOGGING_LEVEL=WARNING \
  -e VLLM_NO_USAGE_STATS=1 \
  mekayelanik/vllm-cpu:amxbf16-latest \
  --model /models/my-model \
  --max-model-len 4096
```

## Building Images Locally

The Dockerfile uses **BuildKit** features for optimized builds. Ensure Docker BuildKit is enabled.

### Basic Build

```bash
# Build from PyPI wheel (Python version auto-detected from available wheels)
docker build \
  --build-arg VLLM_VERSION=0.11.2 \
  --build-arg VARIANT=noavx512 \
  -t my-vllm:local \
  ./docker

# Build with explicit Python version (override auto-detection)
docker build \
  --build-arg VLLM_VERSION=0.11.2 \
  --build-arg VARIANT=noavx512 \
  --build-arg PYTHON_VERSION=3.12 \
  -t my-vllm:local \
  ./docker

# Build from GitHub release (if PyPI unavailable)
docker build \
  --build-arg VLLM_VERSION=0.11.2 \
  --build-arg VARIANT=avx512bf16 \
  --build-arg USE_GITHUB_RELEASE=true \
  -t my-vllm:local \
  ./docker
```

### Optimized Multi-Arch Build with Buildx

For production builds with optimal compression and multi-architecture support:

```bash
# Create buildx builder (one-time setup)
docker buildx create --name vllm-builder --use --driver docker-container

# Build for multiple platforms with zstd compression
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VLLM_VERSION=0.11.2 \
  --build-arg VARIANT=noavx512 \
  --output type=registry,compression=zstd,compression-level=22,compression-threads=0 \
  --cache-from type=registry,ref=myregistry/vllm-cpu:buildcache \
  --cache-to type=registry,ref=myregistry/vllm-cpu:buildcache,mode=max \
  --tag myregistry/vllm-cpu:noavx512-0.11.2 \
  --push \
  ./docker

# Build for local testing (single platform, no push)
docker buildx build \
  --platform linux/amd64 \
  --build-arg VLLM_VERSION=0.11.2 \
  --build-arg VARIANT=noavx512 \
  --load \
  --tag my-vllm:local \
  ./docker
```

### Build Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `VLLM_VERSION` | Yes | - | vLLM version (e.g., 0.11.2) |
| `VARIANT` | No | noavx512 | CPU variant (noavx512, avx512, avx512vnni, avx512bf16, amxbf16) |
| `PYTHON_VERSION` | No | auto | Python version - auto-detects highest available from PyPI/GitHub wheels |
| `USE_GITHUB_RELEASE` | No | false | Use GitHub release wheels instead of PyPI |

### Build Optimization Features

The Dockerfile includes several optimizations for faster builds:

| Feature | Description |
|---------|-------------|
| **Cache Mounts** | apt and uv package caches persist across builds |
| **Bytecode Compilation** | `UV_COMPILE_BYTECODE=1` pre-compiles Python files for faster startup |
| **Multi-Stage Build** | Python version detection in separate stage for efficiency |
| **Layer Ordering** | Dependencies installed before application code for better caching |
| **zstd Compression** | Level 22 compression for smallest image size (GitHub Actions) |

### Build Profiles (GitHub Actions)

When building via GitHub Actions, you can select a build profile:

| Profile | Compression | Use Case |
|---------|-------------|----------|
| `production` | zstd level 22 | Smallest images, slower builds |
| `size-optimized` | zstd level 22 + estargz | Maximum compression |
| `ci` | zstd level 10 | Balanced speed/size |
| `development` | gzip level 1 | Fastest builds |

## API Endpoints

The container exposes the OpenAI-compatible API:

- `GET /health` - Health check
- `GET /v1/models` - List available models
- `POST /v1/completions` - Text completion
- `POST /v1/chat/completions` - Chat completion
- `POST /v1/embeddings` - Embeddings (if model supports)

See [vLLM documentation](https://docs.vllm.ai/en/latest/) for full API reference.

## Troubleshooting

### Image won't start

Check if the variant matches your CPU:
```bash
# Check CPU features
cat /proc/cpuinfo | grep -E "avx512|amx"

# Use noavx512 for maximum compatibility
docker run mekayelanik/vllm-cpu:noavx512-latest ...
```

### Out of memory

Reduce model size or context length:
```bash
docker run ... --max-model-len 2048
```

Or increase KV cache:
```bash
docker run -e VLLM_CPU_KVCACHE_SPACE=16 ...
```

### Slow inference

1. Use the appropriate CPU-optimized variant for your processor
2. Set explicit thread counts matching your physical cores:
   ```bash
   docker run -e OMP_NUM_THREADS=16 -e MKL_NUM_THREADS=16 ...
   ```
3. Bind to specific CPU cores:
   ```bash
   docker run -e VLLM_CPU_OMP_THREADS_BIND="0-15" ...
   ```
4. Ensure HuggingFace cache is persistent (use volumes)

### Container health check fails

Increase start period for large models:
```bash
docker run --health-start-period=300s ...
```

## License

The Docker images and build system are licensed under GPL-3.0.
The vLLM software inside follows Apache License 2.0.
