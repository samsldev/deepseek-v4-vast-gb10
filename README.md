# DeepSeek V4 Flash — MiaAI GB10 profile for Vast.ai

This is a thin container-image adaptation of `MiaAI-Lab/DeepSeek-v4-Flash-One-DGX-Spark` for Vast.ai GB10 offers.

The original project launches a second Docker container with Docker Compose and bind-mounts a set of patches into the runtime image. Vast.ai Docker instances cannot run Docker-in-Docker, so this adaptation bakes those same patch files directly into the pinned runtime image and runs the recipe entrypoint as the Vast instance's own container process.

## What is preserved

- Base runtime image pinned by MiaAI/0xSero
- MiaAI commit pinned to `fdcd538fbf95fb15b2d6850db9613d22b2c889b8`
- DeepSeek V4 Flash 0731 EXL3 / REAP-K216 weights
- TP1 coalescing path
- SparkInfer patches used by MiaAI
- DSpark K5 speculative decoding
- native 432-byte NVFP4 KV records (`VLLM_DSV4_PADDED_NVFP4=0`)
- 384k single-sequence default
- 0.94 GPU/UMA memory utilization
- 24-row CUDA graph capture profile
- long-prefill threshold 1024
- OpenAI-compatible endpoint on port 8888

## What changes versus the original launcher

- No Docker Compose inside the rented instance
- No nested Docker container
- No `network_mode: host`; Vast port mapping is used instead
- No host bind mounts; data lives in Vast container storage while the instance exists
- `ABLATE=0` behavior only. The optional refusal-direction ablation overlay is intentionally not baked in.

## Build

Push this folder to a **public GitHub repository**. The included GitHub Actions workflow builds an ARM64 image and pushes:

`ghcr.io/YOUR_GITHUB_USERNAME/deepseek-v4-flash-vast-gb10:384k`

Then make the GHCR package public (or configure registry credentials in Vast.ai).

See `VAST_TEMPLATE.md` for the exact Vast.ai settings.

## Important caveat

The upstream MiaAI recipe was validated on a native DGX Spark/GB10 host. This adaptation preserves the user-space runtime and patches, but Vast controls the host kernel, NVIDIA driver, memory pressure and OOM policy. Treat the first Vast boot as a compatibility validation. If the 384k profile is too tight, reduce `MAX_MODEL_LEN` before changing other memory/workspace knobs.
