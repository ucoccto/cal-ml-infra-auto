#!/usr/bin/env bash
# checkpoint/결과를 S3로 올린다.
# 사용 예: ./scripts/s3_sync_up.sh checkpoints checkpoints
set -euo pipefail

LOCAL_DIR="${1:-checkpoints}"
S3_PREFIX="${2:-checkpoints}"

aws s3 sync \
  "$LOCAL_DIR/" \
  "s3://$CAL_S3_BUCKET/$S3_PREFIX/" \
  --region "$CAL_AWS_REGION"

echo "Uploaded: $LOCAL_DIR/ -> s3://$CAL_S3_BUCKET/$S3_PREFIX/"
