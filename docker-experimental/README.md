# Docker Experimental

This directory contains experimental Docker-related scripts that are not part of the main PyPI wheel building workflow.

## Files

- **DockerfileModifier.sh**: Generates Dockerfiles for vLLM deployments with AgentDVR integration
- **DOCKER-README.md**: Docker deployment documentation (WIP)

## Status

These files are kept here for potential future use but are **not maintained** as part of the core wheel building process.

The main focus of this repository is building and publishing CPU-optimized vLLM wheels to PyPI, not Docker deployment.

## If You Need Docker

For Docker deployments of vLLM, we recommend:
- Use the official vLLM Docker images
- Or build custom images using the wheels from this project

```dockerfile
FROM debian:trixie-slim
RUN pip install vllm-cpu-avx512bf16
# ... your configuration
```
