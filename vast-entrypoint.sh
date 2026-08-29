#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[vast-mia] %s\n' "$*" >&2; }
warn() { printf '[vast-mia] WARNING: %s\n' "$*" >&2; }
die() { printf '[vast-mia] ERROR: %s\n' "$*" >&2; exit 1; }

ARCH="$(uname -m)"
[[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] || \
  die "This image requires Linux ARM64/aarch64; detected ${ARCH}. Rent a GB10/ARM offer."

if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)"
  [[ -n "$GPU_NAME" ]] && log "GPU: ${GPU_NAME}"
  if [[ -n "$GPU_NAME" && "$GPU_NAME" != *"GB10"* ]]; then
    warn "Expected NVIDIA GB10/SM121. nvidia-smi reports '${GPU_NAME}'. The MiaAI kernel stack is GB10-specific."
  fi
else
  warn "nvidia-smi is not visible. GPU passthrough may be broken."
fi

# All three paths live in Vast container storage and persist while the instance exists.
mkdir -p /models /cache /hf-cache

# Validate the ALLOCATED container-storage size, not just the remaining free
# space. On a healthy first boot the recipe itself consumes ~180+ GB, so a
# restart can legitimately have ~100 GB free on a 300 GB instance.
TOTAL_GIB="$(df -Pk /models | awk 'NR==2 {printf "%d", $2/1024/1024}')"
FREE_GIB="$(df -Pk /models | awk 'NR==2 {printf "%d", $4/1024/1024}')"
log "Container disk: ~${FREE_GIB} GiB free / ~${TOTAL_GIB} GiB total"

# 250 GB-class allocation is the practical minimum for this image; 300-400 GB
# is recommended. Remaining free space only needs runtime/cache headroom.
if [[ "$TOTAL_GIB" -lt 230 ]]; then
  die "Container disk allocation is only ~${TOTAL_GIB} GiB. Recreate with at least 250 GB (300-400 GB recommended)."
fi
if [[ "$FREE_GIB" -lt 30 ]]; then
  die "Only ~${FREE_GIB} GiB free; not enough runtime/cache headroom."
elif [[ "$FREE_GIB" -lt 60 ]]; then
  warn "Only ~${FREE_GIB} GiB free. Runtime/cache headroom is getting tight."
fi

log "Mia profile: MAX_MODEL_LEN=${MAX_MODEL_LEN:-384000}, MAX_NUM_SEQS=${MAX_NUM_SEQS:-1}, GPU_MEMORY_UTILIZATION=${GPU_MEMORY_UTILIZATION:-0.94}"
log "Applying tool-calling compatibility fix..."
bash /patch-run-entrypoint.sh

log "Starting DeepSeek V4 Flash / SparkInfer on ${HOST:-0.0.0.0}:${PORT:-8888}..."
exec /bin/bash /opt/recipe/scripts/entrypoint.sh
