#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/infra"
INSTANCE_ID="$(terraform -chdir="$INFRA_DIR" output -raw instance_id)"
REGION="$(terraform -chdir="$INFRA_DIR" output -raw aws_region)"
PORT="$(terraform -chdir="$INFRA_DIR" output -raw jupyter_port)"
PING="$(aws ssm describe-instance-information --region "$REGION" --query "InstanceInformationList[?InstanceId=='$INSTANCE_ID'].PingStatus | [0]" --output text)"

if [[ "$PING" != "Online" ]]; then
  echo "SSM 상태가 Online이 아닙니다: $PING" >&2
  exit 1
fi

PARAMETERS="{\"portNumber\":[\"$PORT\"],\"localPortNumber\":[\"$PORT\"]}"
echo "Jupyter tunnel: http://127.0.0.1:$PORT/lab"
echo "종료: Ctrl+C"

aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$REGION" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "$PARAMETERS"
