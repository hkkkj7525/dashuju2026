# 配置参数
# 注意：模型在'39'特征下训练（与 model/60_158+39/ 目录名无关）
sequence_length = 60
feature_num = '39'
config = {
    'sequence_length': sequence_length,   # 使用过去60个交易日的数据
    'model_type': 'simplified',
    'd_model': 64,
    'nhead': 4,
    'num_layers': 2,
    'dim_feedforward': 128,
    'batch_size': 8,
    'num_epochs': 30,
    'learning_rate': 1e-5,
    'dropout': 0.3,
    'feature_num': feature_num,
    'max_grad_norm': 5.0,
    'drop_clip': False,
    'warmup_epochs': 3,

    'pairwise_weight': 1,
    'base_weight': 1.0,
    'top5_weight': 3.0,
    'weight_decay': 5e-4,

    'output_dir': f'./model/60_158+39_s123',  # 与现有训练产物目录保持一致
    'data_path': './data',
    'seed': 123,
}