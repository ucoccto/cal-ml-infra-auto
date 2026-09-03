#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/infra"

INSTANCE_ID="$(terraform -chdir="$INFRA_DIR" output -raw instance_id)"
REGION="$(terraform -chdir="$INFRA_DIR" output -raw aws_region)"
VOLUME_ID="$(terraform -chdir="$INFRA_DIR" output -raw data_ebs_volume_id)"
PROFILE_NAME="$(terraform -chdir="$INFRA_DIR" output -raw iam_instance_profile_name)"
ASSOCIATION_ID="$(terraform -chdir="$INFRA_DIR" output -raw bootstrap_association_id)"
FAILED=0

check() {
  local label="$1" ok="$2" detail="$3"
  if [[ "$ok" == "true" ]]; then
    echo "[OK]   $label - $detail"
  else
    echo "[FAIL] $label - $detail"
    FAILED=1
  fi
}

STATE="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].State.Name' --output text)"
[[ "$STATE" == "running" ]] && OK=true || OK=false
check "EC2" "$OK" "state=$STATE id=$INSTANCE_ID"

PROFILE_ARN="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text)"
[[ "$PROFILE_ARN" == *"$PROFILE_NAME" ]] && OK=true || OK=false
check "IAM Instance Profile" "$OK" "arn=$PROFILE_ARN"

PING="$(aws ssm describe-instance-information --region "$REGION" --query "InstanceInformationList[?InstanceId=='$INSTANCE_ID'].PingStatus | [0]" --output text)"
[[ "$PING" == "Online" ]] && OK=true || OK=false
check "SSM" "$OK" "PingStatus=$PING"

ATTACHED_INSTANCE="$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].Attachments[0].InstanceId' --output text)"
ATTACH_STATE="$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].Attachments[0].State' --output text)"
[[ "$ATTACHED_INSTANCE" == "$INSTANCE_ID" && "$ATTACH_STATE" == "attached" ]] && OK=true || OK=false
check "Data EBS" "$OK" "volume=$VOLUME_ID state=$ATTACH_STATE instance=$ATTACHED_INSTANCE"

ASSOC_STATUS="$(aws ssm describe-association --association-id "$ASSOCIATION_ID" --region "$REGION" --query 'AssociationDescription.Status.Name' --output text)"
[[ "$ASSOC_STATUS" == "Success" ]] && OK=true || OK=false
check "Bootstrap Association" "$OK" "status=$ASSOC_STATUS id=$ASSOCIATION_ID"

if [[ "$FAILED" -ne 0 ]]; then
  echo
  echo "환경 검증 실패. TROUBLESHOOTING.md를 확인하세요."
  exit 1
fi

echo
echo "모든 AWS 연결 상태가 정상입니다."
echo "Jupyter: ./local-tools/start-jupyter-tunnel.sh"
