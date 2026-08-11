# 接收外部传入的基础镜像（默认 nvidia/cuda，CPU 时改 python:3.12-slim-bookworm）
ARG IMAGE_NAME=python:3.12-slim-bookworm
FROM ${IMAGE_NAME}

# 防止 apt 缓存使镜像体积膨胀
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 1) 安装 ta-lib C 库（构建期一次性联网下载）
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        make \
        wget \
        ca-certificates \
        && rm -rf /var/lib/apt/lists/* \
    && cd /tmp \
    && wget -q http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz \
    && tar -xzf ta-lib-0.4.0-src.tar.gz \
    && cd ta-lib \
    && ./configure --prefix=/usr >/dev/null \
    && make -j"$(nproc)" >/dev/null \
    && make install >/dev/null \
    && ldconfig \
    && cd / && rm -rf /tmp/ta-lib /tmp/ta-lib-0.4.0-src.tar.gz

# 2) 安装 uv（构建期联网）
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 3) 工作目录固定为 /app
WORKDIR /app

# 4) 复制依赖清单并安装（构建期联网拉 torch、ta-lib Python wheel 等）
# 注意：不使用 --frozen，允许在容器构建时根据 pytorch-cu128 索引自动解析版本
COPY pyproject.toml ./
RUN uv sync

# 5) 复制应用代码
COPY . .

# 6) 环境变量：使用 venv、LD_LIBRARY_PATH、固定随机种子
ENV PATH="/app/.venv/bin:$PATH" \
    LD_LIBRARY_PATH="/usr/lib:/usr/local/lib" \
    PYTHONHASHSEED=123 \
    CUBLAS_WORKSPACE_CONFIG=:4096:8

# 7) 默认命令：保持容器运行，便于赛事方通过 docker exec 执行 init.sh / train.sh / test.sh
CMD ["sleep", "infinity"]
