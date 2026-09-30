FROM node:22-bookworm-slim

ARG AIBOX_UID=1000
ARG AIBOX_GID=1000
ARG CLAUDE_VERSION=latest
ARG CODEX_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        fd-find \
        git \
        git-lfs \
        iproute2 \
        jq \
        less \
        nano \
        ninja-build \
        openssh-client \
        passwd \
        pkg-config \
        procps \
        python3 \
        python3-pip \
        python3-venv \
        python-is-python3 \
        ripgrep \
        rsync \
        tmux \
        unzip \
        vim \
        wget \
        xz-utils \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Keep agent CLI paths stable so OpenShell can bind network policy to exact
# executable paths. Node 22 is supplied by the base image.
RUN npm install -g --prefix /usr/local \
        "@anthropic-ai/claude-code@${CLAUDE_VERSION}" \
        "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Match the host user's numeric identity so a bind-mounted worktree remains
# naturally writable without making the host files world-writable. The Node
# image already has uid/gid 1000; reuse an existing numeric identity when one
# matches the requested IDs.
RUN set -eux; \
    if ! getent group "${AIBOX_GID}" >/dev/null; then \
        groupadd --gid "${AIBOX_GID}" aibox; \
    fi; \
    if ! getent passwd "${AIBOX_UID}" >/dev/null; then \
        useradd --uid "${AIBOX_UID}" --gid "${AIBOX_GID}" \
            --home-dir /sandbox --shell /bin/bash aibox; \
    fi; \
    mkdir -p /sandbox /var/log; \
    chown -R "${AIBOX_UID}:${AIBOX_GID}" /sandbox

COPY policy.yaml /etc/openshell/policy.yaml
COPY bashrc /sandbox/.bashrc
COPY profile /sandbox/.profile
RUN chown "${AIBOX_UID}:${AIBOX_GID}" /sandbox/.bashrc /sandbox/.profile

ENV HOME=/sandbox \
    UV_PYTHON_INSTALL_DIR=/sandbox/.uv/python \
    PATH=/sandbox/.venv/bin:/usr/local/bin:/usr/bin:/bin

WORKDIR /sandbox
USER ${AIBOX_UID}:${AIBOX_GID}

ENTRYPOINT ["/bin/bash"]
