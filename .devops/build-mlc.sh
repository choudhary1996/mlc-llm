#!/usr/bin/env bash
set -e

echo "=== Activate conda ==="
source /opt/conda/etc/profile.d/conda.sh
conda activate mlc-chat-venv

echo "=== Fix git safe directory ==="
git config --global --add safe.directory /workspace

echo "=== Init submodules ==="
cd /workspace
git submodule update --init --recursive

# -------------------------------------------------
# Generate config
# -------------------------------------------------
echo "=== Generate config ==="
mkdir -p build
cd build

printf "\nn\nn\nn\nn\nn\nn\n" | python ../cmake/gen_cmake_config.py

# -------------------------------------------------
# Build MLC
# -------------------------------------------------
echo "=== Build MLC ==="
cmake ..
cmake --build . --parallel 2

# -------------------------------------------------
# Build TVM runtime
# -------------------------------------------------
echo "=== Build TVM runtime ==="
cd ../3rdparty/tvm
mkdir -p build
cd build

cmake ..
cmake --build . --parallel 2

# -------------------------------------------------
# Install TVM Python bindings  ⭐ FIX
# -------------------------------------------------
echo "=== Install TVM Python ==="
cd ../python
pip install -e .

# -------------------------------------------------
# Install MLC Python package
# -------------------------------------------------
echo "=== Install MLC Python ==="
cd /workspace/python
pip install -e . --no-deps

echo "=== Build complete ==="
