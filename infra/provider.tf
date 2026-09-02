# AWS Provider 기본 설정이다.
# 모든 리소스는 기본적으로 서울 리전(ap-northeast-2)에 생성된다.
provider "aws" {
  region = var.aws_region

  # Terraform으로 생성된 리소스임을 쉽게 구분하기 위해 공통 태그를 자동으로 붙인다.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# 현재 Terraform을 실행하는 AWS 계정 ID를 조회한다.
# S3 Bucket 이름을 전 세계에서 유일하게 만들 때 사용한다.
data "aws_caller_identity" "current" {}
