# Vast.ai template settings

Use these values after the image has been pushed to GHCR.

## Docker image

`ghcr.io/YOUR_GITHUB_USERNAME/deepseek-v4-flash-vast-gb10:384k`

Make the GHCR package public, or configure GHCR authentication in Vast.ai.

## Launch mode

**docker ENTRYPOINT**

Do not select Jupyter + SSH or SSH-only for the final serving template. Vast replaces the image ENTRYPOINT in those modes.

## Port

Add TCP port:

`8888`

The Vast host will normally map it to a random public host port. The API inside the container is:

`http://0.0.0.0:8888/v1`

## Disk

Recommended: **300 GB** container storage.

250 GB is a reasonable lower target. The original Mia recipe can benefit from hardlinks on one filesystem, but allocating extra room avoids failures during download/coalescing/cache creation. Disk size cannot be enlarged after instance creation.

## GPU / host filters

- GPU: **GB10**
- CPU architecture: **ARM64 / aarch64**
- 1 GPU
- Host RAM: ideally the full ~125 GB shown for a DGX Spark/GB10 offer

## Environment variables

You do not need to add these; they are defaults baked into the image:

- `MAX_MODEL_LEN=384000`
- `MAX_NUM_SEQS=1`
- `MAX_NUM_BATCHED_TOKENS=8224`
- `GPU_MEMORY_UTILIZATION=0.94`
- `VLLM_DSV4_PADDED_NVFP4=0`
- `KV_FP8_ROPE=0`
- `MODE=dspark`
- `MAX_CUDAGRAPH_CAPTURE_SIZE=24`
- `CUDAGRAPH_CAPTURE_SIZES=6,12,24`
- `VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0`
- `EXTRA_VLLM_ARGS=--long-prefill-token-threshold 1024`
- `PORT=8888`
- `HOST=0.0.0.0`

Optional account-level secret:

- `HF_TOKEN=...` only if Hugging Face rate limits you. The model repository is public, so it is normally unnecessary.

## Optional Docker option

If the Vast template editor accepts it on your account, add:

`--shm-size=16gb`

The original Compose recipe uses a 16 GiB shared-memory allocation. This is less important for the single-GPU TP1 path than for multi-GPU workloads, but matching it is preferable when the platform accepts the option.

## First boot

First boot is intentionally long. It downloads roughly 107 GB of source weights, coalesces TP4 to TP1, builds the K64 draft, compiles/JITs kernels and captures CUDA graphs.

Watch the Vast instance logs. A healthy instance eventually exposes:

- `GET /health`
- OpenAI-compatible API at `/v1`

Example request from a machine that can reach the mapped port:

```bash
curl http://HOST:MAPPED_PORT/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "deepseek-v4-flash-0731",
    "messages": [{"role":"user","content":"Hello"}],
    "temperature": 0,
    "max_completion_tokens": 128
  }'
```

## If 384k fails to boot

The 384k configuration is aggressive and was validated by MiaAI on a native DGX Spark. Vast adds its own container/host environment, so available UMA memory can differ slightly.

Try these overrides in this order:

1. `MAX_MODEL_LEN=350000`
2. `MAX_MODEL_LEN=320000`
3. `MAX_MODEL_LEN=262144`
4. If needed, `GPU_MEMORY_UTILIZATION=0.93`

Do **not** lower `MAX_NUM_BATCHED_TOKENS` below 8224 just to recover memory; Mia's launcher warns that this also sizes the MLA workspace and can lead to later crashes.
