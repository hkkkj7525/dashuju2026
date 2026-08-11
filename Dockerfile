# 接收外部传入的基础镜像（默认 python:3.12-slim-bookworm，GPU 时改 nvidia/cuda）
ARG IMAGE_NAME=python:3.12-slim-bookworm
FROM ${IMAGE_NAME}

# 防止 apt 缓存使镜像体积膨胀
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 1) 安装 uv（构建期联网）
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 2) 工作目录固定为 /app
WORKDIR /app

# 3) 复制依赖清单并安装
#    注意：ta-lib>=0.6.5 已有预编译 manylinux wheel（内含 C 库），无需手动编译
COPY pyproject.toml ./
RUN uv sync

# 4) 复制应用代码
COPY . .

# 5) 环境变量：使用 venv、固定随机种子
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONHASHSEED=123 \
    CUBLAS_WORKSPACE_CONFIG=:4096:8

# 6) 默认命令：保持容器运行，便于赛事方通过 docker exec 执行 init.sh / train.sh / test.sh
CMD ["sleep", "infinity"]
