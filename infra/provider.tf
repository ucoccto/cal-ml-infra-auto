provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# 현재 계정 ID: S3 Bucket 전역 유일 이름 생성에 사용
data "aws_caller_identity" "current" {}

# 상용 AWS / GovCloud / China partition 차이를 안전하게 처리한다.
data "aws_partition" "current" {}
