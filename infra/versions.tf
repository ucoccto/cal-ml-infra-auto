# Terraform 및 AWS Provider 버전을 고정한다.
# 너무 오래된 Provider 사용으로 인한 문법 차이를 줄이기 위한 설정이다.
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
