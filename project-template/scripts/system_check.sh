#!/usr/bin/env bash
# EC2 학습환경을 한 번에 점검한다.
set -euo pipefail

echo "===== NVIDIA ====="
nvidia-smi

echo
echo "===== STORAGE ====="
lsblk
df -h

echo
echo "===== PYTHON/GPU ====="
python scripts/gpu_check.py

echo
echo "===== JUPYTER ====="
systemctl --no-pager status cal-jupyter.service || true

echo
echo "===== S3 ====="
aws s3 ls "s3://$CAL_S3_BUCKET/" --region "$CAL_AWS_REGION"
