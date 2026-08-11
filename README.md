# 代码说明

**队伍名**：666这不阴

## 环境配置

| 组件 | 版本 |
| --- | --- |
| Python | 3.10 – 3.12（容器内 3.12） |
| PyTorch | >=2.6.0（CUDA 12.8 / cuDNN 8） |
| CUDA | 12.x（构建镜像时通过 `--build-arg IMAGE_NAME=nvidia/cuda` 选择基础镜像） |
| uv | 最新版（基础镜像内置） |
| 关键 Python 包 | ta-lib >=0.6.8、pandas >=2.3.2、scikit-learn >=1.7.2、tensorboardx >=2.6.4、tqdm >=4.67.1 |

## 数据

- 训练数据由赛事方在 `data/train.csv` 挂载提供，仅含 OHLCV 与基础行情字段。
- 测试数据由赛事方在 `data/test.csv` 挂载提供，结构与 `train.csv` 相同。
- 训练/测试代码读取 `data/train.csv` 与 `data/test.csv`，不联网下载任何外部数据。
- 字段示例：`股票代码、日期、开盘、收盘、最高、最低、成交量、成交额、振幅、涨跌额、换手率、涨跌幅`。

## 预训练模型

- 本项目**不依赖任何外部预训练模型**。
- 所有模型参数均在 `code/src/train.py` 中从零训练得到，并保存到 `model/<run>/best_model.pth`。
- `code/src/test.py` 在推理时按需加载 `model/60_158+39/best_model.pth` 与 `model/60_158+39_s7/best_model.pth` 进行双模型集成（分数相加后取 Top-5）。

## 算法

### 整体思路介绍

本方案把"每天应该选哪 5 只股票"建模成**排序学习（Learning to Rank）**问题：

1. 以"日"为基本单位构造样本：每只股票在过去 `sequence_length = 60` 个交易日的量价+技术特征作为输入，目标是同一交易日的 5 日相对收益排序。
2. 模型同时学习**单股时序模式**（Transformer Encoder）和**当日股票间交互**（Cross-Stock Attention），输出每只股票的分数。
3. 训练时使用**加权排序损失**（Weighted Listwise + Pairwise 损失），在 Top-5 样本上加权 `top5_weight=3.0`。
4. 推理时，对最新一天的全部可预测股票打分，取分数最高的 5 只，平均权重 0.2。

### 方法的创新点

- **单股 + 跨股双注意力**：Transformer Encoder 捕捉单股时间依赖；Cross-Stock Attention 让当日各股票互相感知，提高排序质量。
- **加权排序损失**：在 Listwise（KL 散度 / Cross Entropy）基础上叠加 Pairwise（Hinge-like）损失，并对 Top-5 样本施以 `top5_weight=3.0` 的额外权重，迫使模型在最有价值的候选上更准确。
- **多 seed 集成**：使用 `seed=123` 与 `seed=7` 两个种子分别训练得到两个模型，推理阶段将两者输出分数相加后取 Top-5，提升稳定性。

### 网络结构

模型类 `StockTransformer`（见 `code/src/model.py`）：

- **PositionalEncoding**：标准时序位置编码。
- **时序编码器**（`nn.TransformerEncoder`）：2 层 / 4 头 / d_model=64 / dim_feedforward=128。
- **FeatureAttention**：对时间维特征做注意力聚合。
- **CrossStockAttention**：在 batch 内对股票维度做多头自注意力，捕捉当日跨股关系。
- **ranking_layers + score_head**：MLP 头输出每只股票的标量分。

输入张量形状：`[batch, num_stocks, seq_len, feature_dim]`
输出张量形状：`[batch, num_stocks]`

### 损失函数

`WeightedRankingLoss`（`code/src/train.py`）：

- **Listwise（KL / 加权 CE）**：
  - `pred_probs = softmax(y_pred / T, dim=1)`
  - `target_probs = softmax(y_true / T, dim=1)`
  - `loss = -(target_probs * log(pred_probs) * weights).sum(dim=1).mean()`
- **Pairwise（Sigmoid-Hinge）**：
  - 仅在真实标签不同的 pair 上计算：`sigmoid(-(pred_i - pred_j) * sign(true_i - true_j))`
  - 权重 = `weights_i + weights_j`，体现 Top-5 重点关注。
- 总损失：`listwise + pairwise_weight * pairwise`，其中 `top_k=5`、`top5_weight=3.0`、`base_weight=1.0`、`pairwise_weight=1.0`、`T=1.0`。

### 数据扩增

- 不使用传统图像式数据增广。
- 在特征工程阶段使用 `TA-Lib` 计算 RSI / MACD / Bollinger / KDJ / OBV / ATR 等技术指标；对 158 个 alpha 特征做 z-score 标准化后用于训练。

### 模型集成

- `code/src/test.py` 加载 2 个训练好的 `best_model.pth`，将每个模型的标量分数相加，得到最终排序，取 Top-5。
- 集成模型列表：
  - `model/60_158+39/best_model.pth`（seed=123）
  - `model/60_158+39_s7/best_model.pth`（seed=7）

### 算法的其他细节

- 训练/验证划分：取数据最后一个月作为验证集，其余为训练集；为验证集首日预留 `sequence_length - 1` 个交易日的上下文。
- 标签构造：`(open_t5 - open_t1) / open_t1`，并过滤 `open_t1 < 1e-4` 的无效样本。
- 缺失值处理：训练时 `dropna(subset=features)`，推理时 `fillna(0.0)`。
- 多进程：使用 `multiprocessing` 加速特征工程（CPU 密集），使用 `spawn` 启动方式，确保 Linux/WSL 兼容。
- 设备优先级：`cuda → mps → cpu`。
- 随机种子：`PYTHONHASHSEED=123`、Python `random`/`numpy`/`torch` 全部固定；`CUBLAS_WORKSPACE_CONFIG=:4096:8` 保证 CUDA 算子确定性。

## 训练流程

`code/src/train.py`：

1. 读取 `data/train.csv`；按最后一个月切分训练/验证集，保留序列上下文。
2. 构造 `stockid2idx` 映射所有股票。
3. 用 `featurework.engineer_features_39` 多进程并行做技术指标特征工程，构造标签 `(open_t5 - open_t1) / open_t1`。
4. `StandardScaler` 标准化 + `joblib.dump(scaler, 'model/<run>/scaler.pkl')`。
5. `featurework.create_ranking_dataset_vectorized` 构造按日排序样本。
6. 实例化 `StockTransformer`，AdamW (lr=1e-5) + CosineAnnealingLR + 3 epoch warmup。
7. 训练 30 epoch，每 epoch 训练 + 验证；以验证集 `final_score` 为指标保存 `best_model.pth`。
8. 训练产物：`model/<run>/{best_model.pth, scaler.pkl, config.json, final_score.txt, log/}`。

## 推理流程

`code/src/test.py`：

1. 读取 `data/train.csv`，取最后一日作为预测日期。
2. 同样的 `engineer_features_39` 多进程特征工程，构造每只股票过去 60 天的特征序列。
3. 加载 `model/60_158+39/scaler.pkl` 进行特征标准化。
4. 加载 `model/60_158+39/best_model.pth` 与 `model/60_158+39_s7/best_model.pth`，输出分数相加。
5. 取分数最高 5 只股票，等权重 0.1999，写入 `output/result.csv`（列名 `stock_id, weight`）。

## 复现步骤（赛事方）

```bash
# 1) 构建镜像（仅构建期联网）
docker buildx build --platform linux/amd64 --build-arg IMAGE_NAME=nvidia/cuda -t bdc2026 .

# 2) 导出镜像（队伍名：666这不阴）
docker save -o "666这不阴.tar" bdc2026:latest

# 3) 复现端加载 + 启动
docker load -i "666这不阴.tar"
docker compose up -d

# 4) 进入容器执行训练 + 预测
docker exec -it bdc2026_app bash /app/init.sh
docker exec -it bdc2026_app bash /app/train.sh
docker exec -it bdc2026_app bash /test.sh
```

## 远程构建（GitHub Actions）

当本地无 Docker 时，可通过 GitHub Actions 自动构建并下载 `666这不阴.tar`：

### 一次性步骤

```bash
# 在 submission 目录下
git init
git add .
git commit -m "init: bdc2026 project"
# 替换 <username> 为你的 GitHub 用户名；仓库建议设为 Private
git remote add origin git@github.com:<username>/bdc2026-666.git
git branch -M main
git push -u origin main
```

### 触发构建

进入 GitHub 仓库页面 → **Actions** tab → 选择左侧 `Build bdc2026 Docker Image` → 右侧 **Run workflow**。

或者推送一个 commit（推到 `main`/`master` 分支也会自动触发）。

### 下载产物

- 等待约 20-40 分钟（构建 + 导出）
- 进入运行结束的 workflow → 底部 **Artifacts** 区域
- 下载 `bdc2026-tar`（包含 `666这不阴.tar` 与 `666这不阴.tar.sha256`）
- 解压得到 `666这不阴.tar`，交给赛事方

> 提示：GitHub 单文件 artifact 上限 10GB，本项目镜像约 3-4GB，符合限制。Retention 默认 14 天，可在 `actions/upload-artifact` 中调整。

## 其他注意事项

- 复现期间**不联网**；`init.sh` / `train.sh` / `test.sh` 内部不调用任何外部网络。
- `featurework.py`、`test.py`、`train.py` 中所有随机性来源（`random` / `numpy` / `torch`）均显式 seed；`PYTHONHASHSEED=123` 在 sh 中固定。
- 训练时间在 RTX 4060 上约 1–2 小时（30 epoch），预测时间远小于 1 分钟，符合 5 分钟预测 / 8 小时训练限制。
- 提交压缩前总大小约 18 MB（含 2 个 best_model.pth + 训练数据），远低于 10 GB 限制。
- 若运行环境无 NVIDIA 容器工具包，可改 `--build-arg IMAGE_NAME=python:3.12-slim-bookworm` 走纯 CPU；模型体量小，CPU 推理也可在 5 分钟内完成。
- 训练时使用 `num_workers=0` 避免 Linux spawn 兼容性问题；特征工程用 `mp.Pool(<=10)` 并行。
