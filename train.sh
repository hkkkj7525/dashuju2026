#!/usr/bin/env bash
# 训练脚本：在 /app/ 下执行；调用 code/src/train.py
# 训练产物写入 /app/model/ 目录

set -e

cd /app

echo "===== train.sh begin ====="
echo "Working dir: $(pwd)"
echo "Start time: $(date)"

# 使用 venv 内的 Python
export PATH="/app/.venv/bin:$PATH"
export LD_LIBRARY_PATH="/usr/lib:/usr/local/lib:${LD_LIBRARY_PATH:-}"
export PYTHONHASHSEED=123
export CUBLAS_WORKSPACE_CONFIG=:4096:8

python code/src/train.py

echo "End time: $(date)"
echo "===== train.sh done ====="
