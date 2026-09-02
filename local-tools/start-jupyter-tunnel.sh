#!/usr/bin/env bash
# 로컬 PC에서 실행하는 스크립트다.
# AWS CLI + Session Manager Plugin + Terraform이 설치되어 있어야 한다.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INSTANCE_ID="$(terraform output -raw instance_id)"
REGION="$(terraform output -raw aws_region)"
PORT="$(terraform output -raw jupyter_port)"
PARAMETERS="{\"portNumber\":[\"$PORT\"],\"localPortNumber\":[\"$PORT\"]}"

echo "Jupyter tunnel: http://127.0.0.1:$PORT/lab"
echo "종료하려면 Ctrl+C를 누르세요."

aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$REGION" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "$PARAMETERS"
