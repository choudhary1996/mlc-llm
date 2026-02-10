#!/usr/bin/env bash
set -e

source /opt/conda/etc/profile.d/conda.sh
conda activate mlc-chat-venv

export LD_LIBRARY_PATH=/workspace/build:/workspace/3rdparty/tvm/build:$LD_LIBRARY_PATH

echo "=== Validate Python ==="
python -c "import tvm; print('TVM OK')"
python -c "import mlc_llm; print('MLC OK')"

echo "=== Validate CLI ==="
mlc_llm chat -h
