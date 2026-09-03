# ============================================================
# S3
# - 원본/가공 데이터
# - Dataset
# - Checkpoint / Output
# - EC2 초기화용 project-template
# ============================================================

resource "aws_s3_bucket" "data" {
  bucket        = local.bucket_name
  force_destroy = var.s3_force_destroy

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3는 실제 디렉터리가 아니라 Object Key prefix를 사용하므로
# raw/, datasets/ 같은 빈 folder marker 객체는 만들지 않는다.
# 실제 데이터가 올라오면 prefix가 자연스럽게 S3 Console에서 폴더처럼 보인다.

# 프로젝트 루트의 project-template 파일들을 S3 bootstrap 영역에 업로드한다.
resource "aws_s3_object" "project_template" {
  for_each = local.project_template_files

  bucket = aws_s3_bucket.data.id
  key    = "bootstrap/project-template/${each.value}"
  source = "${local.project_template_dir}/${each.value}"

  # 로컬 파일 내용 변경을 Terraform이 확실히 감지한다.
  source_hash = filemd5("${local.project_template_dir}/${each.value}")

  depends_on = [
    aws_s3_bucket_public_access_block.data,
    aws_s3_bucket_server_side_encryption_configuration.data,
    aws_s3_bucket_versioning.data
  ]
}

# EC2 전체 설치 스크립트는 Terraform에서 실제 리소스 값(S3/EBS 등)을
# 렌더링한 뒤 S3에 저장한다. State Manager는 AWS-RunRemoteScript로
# 이 파일을 내려받아 실행하므로 긴 shell script를 Association parameter에
# 직접 넣지 않는다.
resource "aws_s3_object" "bootstrap_script" {
  bucket  = aws_s3_bucket.data.id
  key     = local.bootstrap_object_key
  content = local.bootstrap_script

  # bootstrap template/변수가 바뀌면 객체와 Association이 함께 갱신된다.
  source_hash  = sha256(local.bootstrap_script)
  content_type = "text/x-shellscript"

  depends_on = [
    aws_s3_bucket_public_access_block.data,
    aws_s3_bucket_server_side_encryption_configuration.data,
    aws_s3_bucket_versioning.data
  ]
}
