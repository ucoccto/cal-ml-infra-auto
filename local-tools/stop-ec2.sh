#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/infra"
INSTANCE_ID="$(terraform -chdir="$INFRA_DIR" output -raw instance_id)"
REGION="$(terraform -chdir="$INFRA_DIR" output -raw aws_region)"
STATE="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].State.Name' --output text)"

if [[ "$STATE" == "running" ]]; then
  aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION" >/dev/null
  echo "Stop requested: $INSTANCE_ID"
else
  echo "현재 상태: $STATE (stop 요청 생략)"
fi
