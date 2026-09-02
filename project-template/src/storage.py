"""S3와 로컬 파일 간 간단한 업로드/다운로드 도우미."""

from __future__ import annotations

from pathlib import Path

import boto3

from .settings import AWS_REGION, S3_BUCKET


s3 = boto3.client("s3", region_name=AWS_REGION)


def download_file(s3_key: str, local_path: str | Path) -> Path:
    """프로젝트 S3 Bucket의 한 객체를 로컬로 다운로드한다."""
    if not S3_BUCKET:
        raise RuntimeError("CAL_S3_BUCKET 환경변수가 없습니다.")

    destination = Path(local_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    s3.download_file(S3_BUCKET, s3_key, str(destination))
    return destination


def upload_file(local_path: str | Path, s3_key: str) -> None:
    """로컬 파일 하나를 프로젝트 S3 Bucket에 업로드한다."""
    if not S3_BUCKET:
        raise RuntimeError("CAL_S3_BUCKET 환경변수가 없습니다.")

    source = Path(local_path)
    if not source.exists():
        raise FileNotFoundError(source)

    s3.upload_file(str(source), S3_BUCKET, s3_key)
