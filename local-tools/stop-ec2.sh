#!/usr/bin/env bash
# 학습/작업 종료 후 GPU compute 비용을 막기 위해 EC2를 Stop한다.
# Stop 전에 Local NVMe의 필요한 결과를 EBS/S3로 반드시 저장한다.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
INSTANCE_ID="$(terraform output -raw instance_id)"
REGION="$(terraform output -raw aws_region)"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "Stop requested: $INSTANCE_ID"
