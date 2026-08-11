#!/usr/bin/env bash
# 容器启动初始化脚本（在 /app/ 下执行）
# 创建必要的目录、设置可执行权限、打印环境信息

set -e

cd /app

echo "===== init.sh begin ====="
echo "WORKDIR: $(pwd)"
echo "Python: $(python --version 2>&1)"
echo "CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())' 2>&1)"
echo "GPU count: $(python -c 'import torch; print(torch.cuda.device_count())' 2>&1)"

# 容器内所需目录（即使被挂载，也保证存在）
mkdir -p /app/code/src
mkdir -p /app/data
mkdir -p /app/model
mkdir -p /app/output
mkdir -p /app/temp

# 关键脚本可执行
chmod +x /app/init.sh
chmod +x /app/train.sh
chmod +x /test.sh
chmod +x /app/code/src/*.py 2>/dev/null || true

echo "===== init.sh done ====="
