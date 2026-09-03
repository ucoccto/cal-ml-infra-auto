"""프로젝트에서 공통으로 사용하는 경로/환경 설정."""

from __future__ import annotations

import os
from pathlib import Path


# Terraform bootstrap이 /etc/profile.d/cal-project.sh에 넣어준 값을 사용한다.
PROJECT_DIR = Path(os.getenv("CAL_PROJECT_DIR", "/workspace/cal-project"))
CACHE_DIR = Path(os.getenv("CAL_CACHE_DIR", "/workspace/cache"))
S3_BUCKET = os.getenv("CAL_S3_BUCKET", "")
AWS_REGION = os.getenv("CAL_AWS_REGION", "ap-northeast-3")

CHECKPOINT_DIR = PROJECT_DIR / "checkpoints"
OUTPUT_DIR = PROJECT_DIR / "outputs"
LOG_DIR = PROJECT_DIR / "logs"


def ensure_directories() -> None:
    """로컬 작업 디렉터리가 없으면 생성한다."""
    for path in (CACHE_DIR, CHECKPOINT_DIR, OUTPUT_DIR, LOG_DIR):
        path.mkdir(parents=True, exist_ok=True)
