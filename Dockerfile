# Workshop Bootstrap - Development Container
# Repo-agnostic container that supports Python and Node.js projects

FROM python:3.12-slim AS base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install system dependencies including Node.js
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g npm@latest \
    && npm config set update-notifier false \
    && rm -rf /var/lib/apt/lists/*

# Install uv for Python package management
# hadolint ignore=DL3008
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /workspace

# -------------------------------------------
# Development stage - supports all repo types
FROM base AS development

# Install development tools
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    less \
    htop \
    procps \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Set build-time variables
ARG BUILD_TIME="unknown"
ARG VERSION="1.0.0"
ENV BUILD_TIME=${BUILD_TIME} \
    VERSION=${VERSION}

# Default command keeps container alive for development
CMD ["sleep", "infinity"]
