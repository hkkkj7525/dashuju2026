#!/usr/bin/env bash
# ModelWhale GPU 实例中执行：将 c:\Users\hkj\Desktop\比赛\submission\ 拷贝到此机器
# 假设你把整个 submission 目录放在 /root/submission/

set -e

# 0) 确认 Docker
docker --version
nvidia-smi || true

# 1) 进入项目目录
cd /root/submission

# 2) 构建镜像（约 15-30 分钟，下载 ta-lib + torch 2.6+）
docker buildx build \
    --platform linux/amd64 \
    --build-arg IMAGE_NAME=nvidia/cuda \
    -t bdc2026 \
    . 2>&1 | tee /tmp/build.log

# 3) 导出为 .tar（约 1-3 GB）
docker save -o "666这不阴.tar" bdc2026:latest

# 4) 检查大小
ls -lh "666这不阴.tar"

# 5) 验证镜像（在 ModelWhale 实例里跑一下）
docker run --rm --gpus all \
    -v "$(pwd)/data:/app/data" \
    -v "$(pwd)/output:/app/output" \
    -v "$(pwd)/temp:/app/temp" \
    bdc2026:latest \
    bash -c "bash /app/init.sh && bash /app/train.sh && bash /test.sh"

# 6) 看结果
cat output/result.csv

# 7) 下载 666这不阴.tar 到本机
#    在 ModelWhale 的文件浏览器中右键 666这不阴.tar -> 下载
