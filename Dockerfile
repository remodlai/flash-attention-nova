# Flash Attention Nova - Wheel Build Dockerfile
ARG CUDA_VERSION=12.9
ARG PYTHON_VERSION=3.12

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu20.04 AS base
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
        ccache \
        ninja-build \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update -y \
    && apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION} \
    && curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH="/root/.local/bin:$PATH"

WORKDIR /workspace

# Install PyTorch
ARG TORCH_CUDA_ARCH_LIST='9.0'
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system torch torchvision \
        --extra-index-url https://download.pytorch.org/whl/cu$(echo $CUDA_VERSION | cut -d. -f1,2 | tr -d '.')

# Copy source
COPY . .

# Initialize submodules
RUN git submodule update --init csrc/cutlass

# Build parallelism
ARG MAX_JOBS=32
ARG NVCC_THREADS=8
ENV MAX_JOBS=${MAX_JOBS}
ENV NVCC_THREADS=${NVCC_THREADS}

# Build wheel
RUN --mount=type=cache,target=/root/.cache/uv \
    python3 setup.py bdist_wheel --dist-dir=dist

# Verify wheel was created
RUN ls -lh dist/*.whl

