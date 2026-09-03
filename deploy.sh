#!/usr/bin/env bash
# CAL ML AWS 환경을 한 번에 초기화/검증/적용한다.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$ROOT_DIR/infra"
PLAN_FILE="$INFRA_DIR/cal-ml.tfplan"

echo "[1/5] AWS credentials 확인"
aws sts get-caller-identity

echo "[2/5] Terraform init"
terraform -chdir="$INFRA_DIR" init

echo "[3/5] Terraform fmt / validate"
terraform -chdir="$INFRA_DIR" fmt -recursive
terraform -chdir="$INFRA_DIR" validate

echo "[4/5] Terraform plan"
terraform -chdir="$INFRA_DIR" plan -out="$PLAN_FILE"

read -r -p "위 Plan을 적용할까요? (yes 입력): " answer
if [[ "$answer" != "yes" ]]; then
  echo "적용을 취소했습니다."
  exit 0
fi

echo "[5/5] Terraform apply"
terraform -chdir="$INFRA_DIR" apply "$PLAN_FILE"
rm -f "$PLAN_FILE"

echo
echo "Terraform apply 완료."
echo "다음 확인: ./local-tools/verify-environment.sh"
