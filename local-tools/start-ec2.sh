#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/infra"
INSTANCE_ID="$(terraform -chdir="$INFRA_DIR" output -raw instance_id)"
REGION="$(terraform -chdir="$INFRA_DIR" output -raw aws_region)"
STATE="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].State.Name' --output text)"

if [[ "$STATE" == "stopped" ]]; then
  aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION" >/dev/null
elif [[ "$STATE" != "running" ]]; then
  echo "EC2 상태가 start 가능한 상태가 아닙니다: $STATE" >&2
  exit 1
fi

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "SSM Online 대기 중..."
for _ in $(seq 1 60); do
  PING="$(aws ssm describe-instance-information --region "$REGION" --query "InstanceInformationList[?InstanceId=='$INSTANCE_ID'].PingStatus | [0]" --output text)"
  if [[ "$PING" == "Online" ]]; then
    echo "EC2 + SSM ready: $INSTANCE_ID"
    exit 0
  fi
  sleep 5
done

echo "EC2는 running이지만 SSM이 Online이 되지 않았습니다." >&2
exit 1
