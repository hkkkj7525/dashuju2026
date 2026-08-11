#!/usr/bin/env bash
# 测试/预测脚本：容器根目录下执行，进入 /app 跑 test.py
# 结果写入 /app/output/result.csv

set -e

cd /app

echo "===== test.sh begin ====="
echo "Working dir: $(pwd)"
echo "Start time: $(date)"

# 使用 venv 内的 Python
export PATH="/app/.venv/bin:$PATH"
export LD_LIBRARY_PATH="/usr/lib:/usr/local/lib:${LD_LIBRARY_PATH:-}"
export PYTHONHASHSEED=123
export CUBLAS_WORKSPACE_CONFIG=:4096:8

python code/src/test.py

echo "End time: $(date)"
echo "===== test.sh done ====="
