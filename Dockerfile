ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE} AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.10

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials (CMake >= 3.24 installed via pip later)
    build-essential \
    ninja-build \
    git \
    curl \
    wget \
    ca-certificates \
    pkg-config \
    # Python
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    # Rust and Cargo (per doc: required by Hugging Face's tokenizer)
    rustc \
    cargo \
    # Vulkan GPU runtime
    libvulkan-dev \
    libvulkan1 \
    vulkan-tools \
    glslang-tools \
    glslang-dev \
    spirv-tools \
    spirv-headers \
    # Development tools
    gdb \
    ccache \
    clang-format \
    # Utilities
    vim \
    less \
    htop \
    tree \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Set Python as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1

# Install CMake >= 3.24
RUN python -m pip install --upgrade pip setuptools wheel \
    && pip install "cmake>=3.24" ninja

# Verify build dependencies
RUN echo "=== Build Dependencies (per doc Step 1) ===" \
    && cmake --version \
    && git --version \
    && rustc --version \
    && cargo --version \
    && python --version

FROM base AS dev-deps

RUN pip install \
    pytest \
    pytest-cov \
    pytest-xdist \
    black \
    isort \
    pylint \
    mypy \
    build \
    wheel \
    auditwheel \
    patchelf \
    ipython \
    rich


RUN pip install \
    datasets \
    fastapi \
    "ml_dtypes>=0.5.1" \
    openai \
    pandas \
    prompt_toolkit \
    requests \
    safetensors \
    sentencepiece \
    shortuuid \
    tiktoken \
    tqdm \
    transformers \
    uvicorn \
    && pip install torch --extra-index-url https://download.pytorch.org/whl/cpu


FROM dev-deps AS final

ARG GPU=cpu

WORKDIR /workspace

ENV CCACHE_DIR=/ccache \
    CCACHE_COMPILERCHECK=content \
    CCACHE_NOHASHDIR=1 \
    PATH="/usr/lib/ccache:${PATH}"

RUN mkdir -p /ccache && chmod 777 /ccache


COPY <<'EOF' /usr/local/bin/build-entrypoint.sh
#!/bin/bash
set -eo pipefail

# Configuration
: ${NUM_THREADS:=$(nproc)}
: ${GPU:="vulkan"}
: ${RUN_TESTS:="0"}

echo "=============================================="
echo "  MLC-LLM Build Environment"
echo "  Following: https://llm.mlc.ai/docs/install/mlc_llm.html"
echo "=============================================="
echo "GPU Backend: ${GPU}"
echo "Threads: ${NUM_THREADS}"
echo "Run Tests: ${RUN_TESTS}"
echo "=============================================="

cd /workspace

echo ""
echo "=== Step 2: Configure and build ==="

mkdir -p build && cd build


cat > config.cmake << CMAKECFG
set(TVM_SOURCE_DIR 3rdparty/tvm)
set(CMAKE_BUILD_TYPE RelWithDebInfo)
set(USE_CUDA OFF)
set(USE_CUTLASS OFF)
set(USE_CUBLAS OFF)
set(USE_ROCM OFF)
set(USE_METAL OFF)
set(USE_OPENCL OFF)
CMAKECFG

# Enable GPU backend
if [[ ${GPU} == "cuda" ]]; then
    echo "set(USE_CUDA ON)" >> config.cmake
    echo "set(USE_CUBLAS ON)" >> config.cmake
    echo "set(USE_CUTLASS ON)" >> config.cmake
elif [[ ${GPU} == "vulkan" ]] || [[ ${GPU} == "cpu" ]]; then
    echo "set(USE_VULKAN ON)" >> config.cmake
fi

echo "Generated config.cmake:"
cat config.cmake

# Build mlc_llm libraries ( cmake .. && make -j $(nproc))
echo ""
echo "Running: cmake .. -G Ninja"
cmake .. -G Ninja

echo ""
echo "Running: ninja -j ${NUM_THREADS}"
ninja -j ${NUM_THREADS}

cd ..


echo ""
echo "=== Step 3: Install via Python ==="
echo "Running: cd python && pip install -e ."
cd python
pip install -e .
cd ..

echo ""
echo "=== Step 4: Validate installation ==="

# Check for libmlc_llm.so and libtvm_runtime.so
echo "Checking build directory for libraries..."
ls -l ./build/*.so 2>/dev/null || find ./build -name "*.so" -type f | head -10

# Verify CLI (mlc_llm chat -h)
echo ""
echo "Running: mlc_llm chat -h"
mlc_llm chat -h

# Verify Python import (python -c "import mlc_llm; print(mlc_llm)")
echo ""
echo "Running: python -c 'import mlc_llm; print(mlc_llm)'"
python -c "import mlc_llm; print(mlc_llm)"

echo ""
echo "=== Build and validation completed successfully! ==="
# Run tests
if [[ ${RUN_TESTS} == "1" ]]; then
    echo ""
    echo "=== Running tests ==="
    python -m pytest -v tests/python/ -m unittest \
        --ignore=tests/python/integration/ \
        --ignore=tests/python/op/
fi
# Build wheel for distribution

if [[ -n ${BUILD_WHEEL} ]]; then
    echo ""
    echo "=== Building wheel for distribution ==="
    cd python
    pip wheel --no-deps -w ../wheels .
    cd ..
    ls -la wheels/
fi
EOF

RUN chmod +x /usr/local/bin/build-entrypoint.sh

# Development initialization script
COPY <<'EOF' /usr/local/bin/dev-init.sh
#!/bin/bash
cat << 'BANNER'
==============================================
  MLC-LLM Development Environment
  Build docs: https://llm.mlc.ai/docs/install/mlc_llm.html
==============================================
BANNER
echo "Python: $(python --version)"
echo "CMake:  $(cmake --version | head -1)"
echo "Rust:   $(rustc --version)"
echo ""
echo "Build commands (per documentation):"
echo "  1. mkdir -p build && cd build"
echo "  2. python ../cmake/gen_cmake_config.py"
echo "  3. cmake .. && make -j \$(nproc)"
echo "  4. cd ../python && pip install -e ."
echo ""
echo "Or use the automated build:"
echo "  build-entrypoint.sh"
echo ""
echo "Quick commands:"
echo "  pytest tests/python/ -m unittest  # Run tests"
echo "  black python/                     # Format code"
echo "  mlc_llm chat -h                   # CLI help"
echo "=============================================="
EOF

RUN chmod +x /usr/local/bin/dev-init.sh
RUN echo 'source /usr/local/bin/dev-init.sh' >> /etc/bash.bashrc

# Container metadata
LABEL org.opencontainers.image.source="https://github.com/mlc-ai/mlc-llm"
LABEL org.opencontainers.image.description="MLC-LLM Multipurpose Docker Image (Dev + Build)"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Default: Build mode (non-interactive)
# Override with /bin/bash for development mode (interactive)
ENTRYPOINT ["/usr/local/bin/build-entrypoint.sh"]
CMD []
