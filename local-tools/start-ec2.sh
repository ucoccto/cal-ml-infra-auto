#!/usr/bin/env bash
# 비용 절감을 위해 학습을 시작할 때만 EC2를 Start한다.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
INSTANCE_ID="$(terraform output -raw instance_id)"
REGION="$(terraform output -raw aws_region)"
aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "EC2 is running: $INSTANCE_ID"
