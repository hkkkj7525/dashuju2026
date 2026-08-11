# =============================================================
# ModelWhale 一键训练 + 预测脚本
# 在 Notebook 中运行这个 cell 即可
# =============================================================
# 0) 准备目录
import os, subprocess, sys
os.makedirs('/home/mw/project/data', exist_ok=True)
os.makedirs('/home/mw/project/output', exist_ok=True)
os.makedirs('/home/mw/project/temp', exist_ok=True)

# 1) 查看 GPU
subprocess.run(['nvidia-smi'], shell=False)

# 2) 准备依赖
for cmd in [['python', '--version']]:
    print(subprocess.run(cmd, capture_output=True, text=True).stdout)

# 3) 检查项目文件
print('\n=== /home/mw/project 内容 ===')
for root, dirs, files in os.walk('/home/mw/project'):
    for f in files:
        full = os.path.join(root, f)
        size = os.path.getsize(full) / 1024
        if size > 1:  # 跳过小于 1KB 的 .pyc
            print(f'{size:>10.1f} KB  {full}')
