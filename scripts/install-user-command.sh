#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$HOME/.local/bin"
ln -sfn "$ROOT/bin/aibox" "$HOME/.local/bin/aibox"
echo "Installed symlink: $HOME/.local/bin/aibox -> $ROOT/bin/aibox"
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo 'Note: add $HOME/.local/bin to PATH.' ;;
esac
