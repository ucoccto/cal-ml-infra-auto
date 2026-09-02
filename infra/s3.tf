# 원본/가공 데이터, checkpoint, 최종 결과를 장기 보관할 S3 Bucket이다.
resource "aws_s3_bucket" "data" {
  bucket = local.bucket_name

  # 실습 종료 후 terraform destroy만으로 데이터를 삭제하고 싶다면 true로 바꿀 수 있다.
  # 기본 false는 실수로 학습 데이터를 삭제하는 것을 방지한다.
  force_destroy = false

  tags = {
    Name = local.bucket_name
  }
}

# 외부 공개를 전면 차단한다.
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 저장 객체를 서버 측 암호화한다.
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 실수로 파일을 덮어써도 복구 가능하도록 Versioning을 켠다.
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 논리적 데이터 영역을 미리 생성한다.
resource "aws_s3_object" "folders" {
  for_each = toset([
    "raw/",
    "raw/stl/",
    "processed/",
    "processed/voxel/",
    "processed/projection/",
    "processed/gradient/",
    "processed/curvature/",
    "processed/levelset/",
    "processed/geometry/",
    "augmented/",
    "datasets/",
    "datasets/train/",
    "datasets/validation/",
    "datasets/test/",
    "checkpoints/",
    "outputs/",
    "bootstrap/"
  ])

  bucket  = aws_s3_bucket.data.id
  key     = each.value
  content = ""
}

# 로컬 project-template 디렉터리의 파일들을 S3에 업로드한다.
# EC2 user_data가 이 위치를 내려받아 Jupyter 프로젝트를 자동으로 만든다.
resource "aws_s3_object" "project_template" {
  for_each = local.project_template_files

  bucket = aws_s3_bucket.data.id
  key    = "bootstrap/project-template/${each.value}"
  source = "${path.module}/project-template/${each.value}"

  # 로컬 파일이 바뀌면 Terraform이 변경을 감지하도록 한다.
  etag = filemd5("${path.module}/project-template/${each.value}")

  depends_on = [aws_s3_bucket_versioning.data]
}
