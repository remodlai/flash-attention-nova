# Flash Attention Nova - Wheel Build Dockerfile
# syntax=docker/dockerfile:1.4
ARG CUDA_VERSION=12.9.1
ARG PYTHON_VERSION=3.12

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04 AS base
ARG CUDA_VERSION
ARG PYTHON_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# Install Python and build tools
RUN apt-get update -y \
    && apt-get install -y --fix-missing \
        software-properties-common \
        git \
        curl \
        wget \
        ninja-build \
        openssh-client \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update -y \
    && apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION} \
    && curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH="/root/.local/bin:$PATH"

WORKDIR /workspace

# Install PyTorch
ARG TORCH_CUDA_ARCH_LIST='8.0 8.6 8.9 9.0 9.0a'
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system torch torchvision \
        --extra-index-url https://download.pytorch.org/whl/cu$(echo $CUDA_VERSION | cut -d. -f1,2 | tr -d '.')

# Install build dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system packaging wheel setuptools ninja cmake

# Copy source
COPY . .

# Initialize submodules with SSH access
RUN --mount=type=ssh \
    mkdir -p /root/.ssh && \
    ssh-keyscan github.com >> /root/.ssh/known_hosts && \
    git submodule update --init csrc/cutlass

# Build environment variables
ARG MAX_JOBS=32
ARG NVCC_THREADS=8
ARG NOVA_TARGET_DEVICE="cuda"
ARG CMAKE_BUILD_TYPE="Release"
ARG VERBOSE="0"

ENV MAX_JOBS=${MAX_JOBS}
ENV NVCC_THREADS=${NVCC_THREADS}
ENV NOVA_TARGET_DEVICE=${NOVA_TARGET_DEVICE}
ENV CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
ENV VERBOSE=${VERBOSE}

# sccache configuration
ARG USE_SCCACHE=1
ARG SCCACHE_BUCKET_NAME=lexiq-nova-build-sccache
ARG SCCACHE_REGION_NAME=us-west-2
ARG SCCACHE_S3_NO_CREDENTIALS=1

# Build wheel with sccache
RUN --mount=type=cache,target=/root/.cache/uv \
    if [ "$USE_SCCACHE" = "1" ]; then \
        uv pip install --system sccache && \
        export SCCACHE_BUCKET=${SCCACHE_BUCKET_NAME} && \
        export SCCACHE_REGION=${SCCACHE_REGION_NAME} && \
        export SCCACHE_S3_NO_CREDENTIALS=${SCCACHE_S3_NO_CREDENTIALS} && \
        export CMAKE_C_COMPILER_LAUNCHER=sccache && \
        export CMAKE_CXX_COMPILER_LAUNCHER=sccache && \
        export CMAKE_CUDA_COMPILER_LAUNCHER=sccache && \
        sccache --show-stats && \
        python3 setup.py bdist_wheel --dist-dir=dist && \
        sccache --show-stats; \
    else \
        python3 setup.py bdist_wheel --dist-dir=dist; \
    fi

# Verify wheel was created
RUN ls -lh dist/*.whl

