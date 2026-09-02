#!/usr/bin/env bash
# S3의 특정 prefix를 로컬 cache로 내려받는다.
# 사용 예: ./scripts/s3_sync_down.sh datasets/train /workspace/cache/train
set -euo pipefail

S3_PREFIX="${1:-datasets/train}"
LOCAL_DIR="${2:-/workspace/cache/train}"

mkdir -p "$LOCAL_DIR"
aws s3 sync \
  "s3://$CAL_S3_BUCKET/$S3_PREFIX/" \
  "$LOCAL_DIR/" \
  --region "$CAL_AWS_REGION"

echo "Downloaded: s3://$CAL_S3_BUCKET/$S3_PREFIX/ -> $LOCAL_DIR/"
