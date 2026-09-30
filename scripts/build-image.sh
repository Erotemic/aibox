#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${AIBOX_IMAGE:-aibox:local}"
UID_VALUE="${AIBOX_UID:-$(id -u)}"
GID_VALUE="${AIBOX_GID:-$(id -g)}"
CLAUDE_VERSION="${AIBOX_CLAUDE_VERSION:-latest}"
CODEX_VERSION="${AIBOX_CODEX_VERSION:-latest}"

if [[ "$UID_VALUE" == 0 || "$GID_VALUE" == 0 ]]; then
    echo "error: aibox workload must use a non-root UID/GID" >&2
    exit 1
fi

echo "==> Building $IMAGE for host identity ${UID_VALUE}:${GID_VALUE}"
docker build \
    --build-arg "AIBOX_UID=$UID_VALUE" \
    --build-arg "AIBOX_GID=$GID_VALUE" \
    --build-arg "CLAUDE_VERSION=$CLAUDE_VERSION" \
    --build-arg "CODEX_VERSION=$CODEX_VERSION" \
    -t "$IMAGE" \
    "$ROOT/image"

echo "==> Built $IMAGE"
docker image inspect "$IMAGE" --format 'user={{.Config.User}} workdir={{.Config.WorkingDir}}'
