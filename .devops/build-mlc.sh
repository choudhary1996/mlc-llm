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

echo "=== Generate config ==="
mkdir -p build
cd build

printf "\nn\nn\nn\nn\nn\nn\n" | python ../cmake/gen_cmake_config.py

echo "=== Build MLC ==="
cmake ..
cmake --build . --parallel 2

echo "=== Build TVM runtime ==="
cd ../3rdparty/tvm
mkdir -p build
cd build
cmake ..
cmake --build . --parallel 2

echo "=== Build complete ==="
