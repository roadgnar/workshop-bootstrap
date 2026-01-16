# Workshop Bootstrap - Development Container
# Multi-stage build for efficient caching

FROM python:3.12-slim as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# -------------------------------------------
# Development stage
FROM base as development

# Install development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    less \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY demo-site/requirements.txt /workspace/demo-site/requirements.txt
RUN pip install -r /workspace/demo-site/requirements.txt

# Set build-time variables
ARG BUILD_TIME="unknown"
ARG VERSION="1.0.0"
ENV BUILD_TIME=${BUILD_TIME} \
    VERSION=${VERSION} \
    FLASK_ENV=development

# Default command keeps container alive for development
CMD ["sleep", "infinity"]

# -------------------------------------------
# Production stage (for running the demo)
FROM base as production

# Copy and install only production dependencies
COPY demo-site/requirements.txt /workspace/demo-site/requirements.txt
RUN pip install -r /workspace/demo-site/requirements.txt

# Copy application code
COPY demo-site/ /workspace/demo-site/

# Set production environment
ARG BUILD_TIME="unknown"
ARG VERSION="1.0.0"
ENV BUILD_TIME=${BUILD_TIME} \
    VERSION=${VERSION} \
    FLASK_ENV=production \
    PORT=8080

WORKDIR /workspace/demo-site

EXPOSE 8080

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]

