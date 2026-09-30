# AGENTS.md

Keep `aibox` small and auditable. Its current purpose is to bootstrap and launch a single-host OpenShell/Docker GPU sandbox, not to become another general orchestration framework.

Security-sensitive invariants:

- Never mount the Docker socket into a sandbox.
- Never mount the whole host home directory.
- Default to one explicit Git worktree bind-mounted at `/sandbox/repo`.
- Keep GPU selection explicit through NVIDIA CDI identifiers.
- Keep outbound network access deny-by-default; add narrow endpoint/binary rules instead of a global internet bypass.
- Treat the OpenShell gateway as a private per-user operator service because aibox enables raw bind-mount driver config.
- Preserve the distinction between this container boundary and a VM boundary.

The default workload image is built locally from `image/Dockerfile` and must preserve the host numeric UID/GID so bind-mounted worktrees remain writable without weakening host permissions.

Prefer shell scripts and existing OpenShell functionality until complexity justifies a larger implementation.
