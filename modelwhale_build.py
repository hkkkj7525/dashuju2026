"""
================================================================
ModelWhale 一键构建脚本
================================================================
使用方法：
1) 把 c:\Users\hkj\Desktop\比赛\submission.zip 上传到 ModelWhale /home/mw/
2) 在 ModelWhale 第一个 cell 里粘贴此脚本运行
3) 等待构建完成（约 15-30 分钟）
4) 在 /home/mw/666这不阴.tar 即可下载
================================================================
"""

import os
import subprocess
import sys
import time

os.chdir('/home/mw')

# === 0) 准备环境 ===
print('=' * 60)
print('[0] 准备环境')
print('=' * 60)
os.makedirs('/home/mw/project', exist_ok=True)

# 解压项目（如果未解压）
if not os.path.exists('/home/mw/project/Dockerfile'):
    if os.path.exists('/home/mw/submission.zip'):
        print('解压 submission.zip ...')
        subprocess.run(['unzip', '-o', 'submission.zip', '-d', 'project'], check=True)
    else:
        print('ERROR: /home/mw/submission.zip 不存在，请先上传', file=sys.stderr)
        sys.exit(1)

os.chdir('/home/mw/project')
print(f'当前目录: {os.getcwd()}')

# 创建必要目录
for d in ['data', 'output', 'temp']:
    os.makedirs(f'/home/mw/project/{d}', exist_ok=True)

# 检查 GPU
print('\n=== GPU 信息 ===')
try:
    out = subprocess.run(['nvidia-smi'], capture_output=True, text=True, timeout=10)
    print(out.stdout[:500])
except Exception as e:
    print(f'nvidia-smi 失败: {e}')

# === 1) 检查 docker ===
print('\n' + '=' * 60)
print('[1] 检查 docker')
print('=' * 60)
try:
    out = subprocess.run(['docker', '--version'], capture_output=True, text=True, timeout=10)
    print(f'docker: {out.stdout.strip()}')
except FileNotFoundError:
    print('docker 不在 PATH 中，尝试以下方式加载 docker:')
    # 尝试用 sudo 加载 docker
    for path in ['/usr/bin/docker', '/usr/local/bin/docker', '/opt/docker/bin/docker']:
        if os.path.exists(path):
            print(f'找到 docker: {path}')
            break
    print('ERROR: docker 不可用', file=sys.stderr)
    print('提示：ModelWhale 容器里通常不能直接用 docker（因安全沙箱）', file=sys.stderr)
    print('   请改用方案 B：在 ModelWhale 直接跑训练 + 预测，然后手工制作 tar', file=sys.stderr)
    sys.exit(1)

# === 2) 构建镜像 ===
print('\n' + '=' * 60)
print('[2] 构建 docker 镜像 bdc2026（需 15-30 分钟）')
print('=' * 60)
build_start = time.time()
result = subprocess.run([
    'docker', 'buildx', 'build',
    '--platform', 'linux/amd64',
    '--build-arg', 'IMAGE_NAME=nvidia/cuda',
    '-t', 'bdc2026',
    '--load',
    '.'
], capture_output=True, text=True)
print(f'构建用时: {time.time() - build_start:.1f} 秒')
print('STDOUT 末尾:', result.stdout[-2000:])
if result.returncode != 0:
    print('STDERR:', result.stderr[-2000:])
    sys.exit(result.returncode)

# === 3) 导出镜像 ===
print('\n' + '=' * 60)
print('[3] 导出镜像为 666这不阴.tar')
print('=' * 60)
result = subprocess.run([
    'docker', 'save', '-o', '/home/mw/666这不阴.tar', 'bdc2026:latest'
], capture_output=True, text=True)
if result.returncode != 0:
    print('导出失败:', result.stderr)
    sys.exit(result.returncode)

tar_size = os.path.getsize('/home/mw/666这不阴.tar') / (1024**3)
print(f'666这不阴.tar 大小: {tar_size:.2f} GB')

# === 4) 验证镜像 ===
print('\n' + '=' * 60)
print('[4] 验证镜像能正常运行')
print('=' * 60)
# 跑 init.sh
result = subprocess.run([
    'docker', 'run', '--rm', '--gpus', 'all',
    '-v', '/home/mw/project/data:/app/data',
    '-v', '/home/mw/project/output:/app/output',
    '-v', '/home/mw/project/temp:/app/temp',
    'bdc2026:latest',
    'bash', '-c', 'bash /app/init.sh && bash /test.sh'
], capture_output=True, text=True, timeout=600)
print('STDOUT 末尾:', result.stdout[-1500:])
if result.returncode != 0:
    print('STDERR:', result.stderr[-1500:])

# === 5) 显示 result.csv ===
print('\n' + '=' * 60)
print('[5] result.csv 内容')
print('=' * 60)
result_csv = '/home/mw/project/output/result.csv'
if os.path.exists(result_csv):
    with open(result_csv) as f:
        print(f.read())
else:
    print(f'ERROR: {result_csv} 不存在')

print('\n' + '=' * 60)
print('完成！请在 ModelWhale 文件浏览器中下载：')
print('  /home/mw/666这不阴.tar')
print('=' * 60)
