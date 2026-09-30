# aibox

`aibox` is a deliberately small bootstrap/wrapper for running GPU-visible coding-agent sandboxes on one Linux workstation. It is analogous to `aivm`, but this first version is intentionally narrow: get a useful container sandbox working on the target GPU host now, then decide later whether it deserves a larger architecture.

The backend is NVIDIA OpenShell with its Docker compute driver. OpenShell supplies the sandbox supervisor, seccomp/Landlock enforcement, network policy, provider integration, and lifecycle management. `aibox` adds host validation, one explicitly selected host worktree bind mount, NVIDIA CDI GPU selection, a locally built workload image, and a small CLI.

## Target host

This was prepared for the supplied machine:

- Ubuntu 22.04.5 / Linux 6.8
- Docker Engine 29.8
- NVIDIA driver 610.57.04
- 4 x RTX PRO 6000 Blackwell GPUs
- NVIDIA Container Toolkit 1.20 with CDI devices
- cgroup v2
- AppArmor, seccomp, Landlock, and user namespaces enabled

The supplied diagnostics already show the host-side prerequisites are present.

## Why a local workload image

`aibox` builds `aibox:local` itself so the bootstrap does not depend on an external OpenShell workload catalog or a mutable `base` alias.

The image contains:

- Debian 12 userspace with Node.js 22
- Git, build tools, CMake/Ninja, tmux, rsync, ripgrep, jq, SSH client
- Python 3 plus `uv`
- Node.js 22 / npm
- Claude Code and OpenAI Codex CLI
- an OpenShell development policy with narrow access to the model endpoints, GitHub, PyPI/PyTorch wheels, and npm

The image is built with your **numeric host UID/GID**. That is important: the sandbox can edit the real bind-mounted Git worktree without `chmod 777`, ACL hacks, or running the agent as root.

## Security model

This is **not VM isolation**. The sandbox shares the host Linux kernel and NVIDIA kernel driver.

The wrapper intentionally does **not** mount:

- the Docker socket
- the host home directory
- host SSH configuration or keys
- arbitrary additional host paths

It bind-mounts one selected Git worktree at `/sandbox/repo`. The wrapper refuses `/`, refuses the whole home directory, and normally requires the selected path to be a Git worktree.

OpenShell disables raw Docker bind mounts by default. `aibox` enables them and disables OpenShell external-resource admission because this immediate workflow requires editing the real host worktree. This is an operator-level weakening: treat the local OpenShell gateway as a private per-user service, not a shared endpoint for mutually untrusted callers.

## Bootstrap

From the unpacked `aibox` repository:

```bash
./bootstrap.sh
```

It will:

1. install OpenShell v0.1.1 from NVIDIA's official installer as the native Debian package if needed;
2. install the Docker gateway configuration under `~/.config/openshell/`;
3. validate and restart the user gateway;
4. build `aibox:local` for your current UID/GID;
5. run host diagnostics;
6. run an end-to-end GPU + worktree write-through smoke test on GPU 0.

If you already have a different OpenShell gateway configuration, bootstrap refuses to replace it unless you say:

```bash
./bootstrap.sh --force-config
```

It backs the old file up first.

OpenShell is pinned to v0.1.1 by default so this bootstrap does not silently move underneath you. Optional version controls:

```bash
AIBOX_OPENSHELL_VERSION=vX.Y.Z ./bootstrap.sh
AIBOX_CLAUDE_VERSION=latest AIBOX_CODEX_VERSION=latest ./scripts/build-image.sh
```

## Use it

Open a sandbox shell on GPU 0:

```bash
./bin/aibox shell --gpu 0 ~/code/myrepo
```

The repository appears as `/sandbox/repo`, and the shell starts there.

Use multiple GPUs:

```bash
./bin/aibox shell --gpu 0,1 ~/code/myrepo
```

Use every numeric CDI GPU:

```bash
./bin/aibox shell --gpu all ~/code/myrepo
```

Run Claude Code:

```bash
./bin/aibox run --gpu 0 ~/code/myrepo -- claude
```

Run Codex with OpenShell as the outer sandbox:

```bash
./bin/aibox run --gpu 0 ~/code/myrepo -- codex --sandbox danger-full-access
```

Codex has its own Linux sandbox. Nested Landlock/seccomp isolation can fail inside an
already-sandboxed container, so the command above disables Codex's *inner* filesystem
sandbox while leaving OpenShell's outer filesystem and network policy in force. It does
not disable Codex approval prompts.

If Codex's ChatGPT OAuth flow needs its local callback, create the sandbox with a forward:

```bash
./bin/aibox run --gpu 0 --forward 1455 ~/code/myrepo -- codex --sandbox danger-full-access
```

The exact OAuth behavior is Codex-version-dependent, so the port forward is opt-in rather than always exposed.

Sandboxes stay around after the exec'd agent exits so you can inspect or re-enter them:

```bash
./bin/aibox list
./bin/aibox exec <sandbox-name> -- nvidia-smi
./bin/aibox delete <sandbox-name>
```

## Credentials

The image has enough network policy for interactive Claude/Codex authentication, but it does not copy host credentials into the container.

For API-key workflows, OpenShell providers are preferable because OpenShell can bind credentials to allowed endpoints. For example, after importing/configuring the appropriate provider profile, attach it with:

```bash
./bin/aibox run --provider claude-code --gpu 0 ~/code/myrepo -- claude
```

or the corresponding Codex provider.

For the immediate interactive workflow, you can also authenticate from inside the sandbox. Its home is `/sandbox`, so login state persists with that sandbox until you delete it.

## Network policy

The workload image has a deny-by-default OpenShell policy with explicit development destinations. It currently includes:

- Anthropic / Claude endpoints
- OpenAI / Codex endpoints
- GitHub source endpoints
- PyPI and PyTorch wheel hosts
- npm registry

Everything else remains blocked unless an attached provider adds a rule or you add one explicitly.

Inspect denials:

```bash
./bin/aibox logs <sandbox-name> --level warn --since 5m
```

Add one endpoint for one or more exact binary paths:

```bash
./bin/aibox exec <sandbox-name> -- command -v uv
./bin/aibox allow <sandbox-name> huggingface.co:443 /usr/local/bin/uv /usr/bin/python3
```

There is intentionally no `--allow-internet` shortcut.

## Diagnostics

Host/runtime checks:

```bash
./bin/aibox doctor
```

Full GPU + OpenShell + bind-mount smoke test:

```bash
./bin/aibox smoke --gpu 0
```

The smoke test creates a temporary Git repository and sandbox, checks `nvidia-smi -L` inside it, writes through `/sandbox/repo`, verifies the write on the host, prints the effective policy, then deletes the temporary sandbox.

Rebuild the workload image after changing tools or when you want fresh agent CLI versions:

```bash
./scripts/build-image.sh
```

Optional convenience symlink:

```bash
./scripts/install-user-command.sh
```

## Scope for later

If this proves useful, the next layer could add per-project profiles, cache volumes, policy-advisor approval helpers, provider setup, service/port profiles, image version pinning, and perhaps a direct-Docker fallback. Those are deliberately outside this first bootstrap.

## Upstream references

- OpenShell installation: https://docs.nvidia.com/openshell/latest/about/installation
- Run an agent: https://docs.nvidia.com/openshell/latest/about/run-your-first-agent
- Docker compute driver / GPU / mounts: https://docs.nvidia.com/openshell/latest/reference/sandbox-compute-drivers
- Policy schema: https://docs.nvidia.com/openshell/latest/reference/policy-schema
- Docker CDI: https://docs.docker.com/reference/cli/docker/container/run/#cdi-devices
