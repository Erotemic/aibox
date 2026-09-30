#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$ROOT/config/gateway.toml"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/openshell"
CONFIG_DST="$CONFIG_DIR/gateway.toml"

usage() {
    cat <<'USAGE'
Usage: ./bootstrap.sh [--force-config] [--skip-install] [--skip-smoke]

Installs/configures NVIDIA OpenShell for a local Docker GPU sandbox.

Options:
  --force-config  Replace an existing OpenShell gateway config (backs it up).
  --skip-install  Require openshell to already be installed.
  --skip-smoke    Skip the end-to-end GPU/worktree smoke test.

Environment:
  AIBOX_OPENSHELL_VERSION     OpenShell release tag. Default: v0.1.1.
  AIBOX_OPENSHELL_INSTALL_URL Override the versioned official installer URL.
USAGE
}

force_config=0
skip_install=0
skip_smoke=0
while (($#)); do
    case "$1" in
        --force-config) force_config=1 ;;
        --skip-install) skip_install=1 ;;
        --skip-smoke) skip_smoke=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "error: required command not found: $1" >&2
        exit 1
    }
}

need_cmd curl
need_cmd docker
need_cmd python3

if ! docker info >/dev/null 2>&1; then
    echo "error: Docker daemon is not reachable as user $USER" >&2
    exit 1
fi

if ! command -v openshell >/dev/null 2>&1; then
    if ((skip_install)); then
        echo "error: openshell is not installed" >&2
        exit 1
    fi
    echo "==> Installing OpenShell from NVIDIA's official installer"
    openshell_version="${AIBOX_OPENSHELL_VERSION:-v0.1.1}"
    install_url="${AIBOX_OPENSHELL_INSTALL_URL:-https://raw.githubusercontent.com/NVIDIA/OpenShell/${openshell_version}/install.sh}"
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    curl -fsSL "$install_url" -o "$tmp"
    # Force the native Debian package. The aibox gateway config below is the
    # per-user Debian-package config, not the system-wide OpenShell snap config.
    OPENSHELL_INSTALL_METHOD=deb OPENSHELL_VERSION="$openshell_version" sh "$tmp"
    rm -f "$tmp"
    trap - EXIT
fi

mkdir -p "$CONFIG_DIR"
if [[ -e "$CONFIG_DST" ]] && ! cmp -s "$CONFIG_SRC" "$CONFIG_DST"; then
    if ((!force_config)); then
        cat >&2 <<EOF2
error: $CONFIG_DST already exists and differs from aibox's config.
Refusing to overwrite it.

Re-run with --force-config to back it up and install the aibox config, or merge
these settings yourself:
  $CONFIG_SRC
EOF2
        exit 1
    fi
    stamp="$(date +%Y%m%dT%H%M%S)"
    backup="$CONFIG_DST.aibox-backup-$stamp"
    cp -a "$CONFIG_DST" "$backup"
    echo "==> Backed up existing gateway config to: $backup"
fi
install -m 600 "$CONFIG_SRC" "$CONFIG_DST"
echo "==> Installed gateway config: $CONFIG_DST"

if command -v openshell-gateway >/dev/null 2>&1; then
    echo "==> Validating gateway config"
    openshell-gateway config preflight --path "$CONFIG_DST"
fi

if command -v systemctl >/dev/null 2>&1; then
    echo "==> Restarting OpenShell user gateway"
    systemctl --user restart openshell-gateway
fi

echo "==> Checking gateway"
openshell status

echo "==> Building the local aibox workload image"
"$ROOT/scripts/build-image.sh"

echo "==> Running host checks"
"$ROOT/bin/aibox" doctor

if ((!skip_smoke)); then
    echo "==> Running end-to-end GPU/worktree smoke test on GPU 0"
    "$ROOT/bin/aibox" smoke --gpu 0
fi

cat <<'DONE'

Bootstrap complete.

Try:
  ./bin/aibox shell --gpu 0 /path/to/repo
  ./bin/aibox run   --gpu 0 /path/to/repo -- claude
  ./bin/aibox run   --gpu 0 --forward 1455 /path/to/repo -- codex

The repository is mounted at /sandbox/repo inside the sandbox.
DONE
