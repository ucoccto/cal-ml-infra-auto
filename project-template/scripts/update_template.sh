#!/usr/bin/env bash
# Terraform에서 project-template을 수정해 S3에 반영한 뒤,
# 기존 EC2에 최신 템플릿 파일을 다시 내려받을 때 사용한다.
set -euo pipefail

aws s3 sync \
  "s3://$CAL_S3_BUCKET/bootstrap/project-template/" \
  "$CAL_PROJECT_DIR/" \
  --region "$CAL_AWS_REGION" \
  --exclude "checkpoints/*" \
  --exclude "outputs/*" \
  --exclude "logs/*" \
  --exclude "data/*"

echo "Project template updated."
