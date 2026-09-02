#!/usr/bin/env bash
# 로컬 PC에서 EC2 shell에 접속한다.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INSTANCE_ID="$(terraform output -raw instance_id)"
REGION="$(terraform output -raw aws_region)"
aws ssm start-session --target "$INSTANCE_ID" --region "$REGION"
