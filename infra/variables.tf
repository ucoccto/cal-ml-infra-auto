# ------------------------------
# 공통 설정
# ------------------------------
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "availability_zone" {
  description = "EC2와 EBS를 생성할 가용 영역"
  type        = string
  default     = "ap-northeast-2a"
}

variable "project_name" {
  description = "AWS 리소스 이름 앞에 사용할 프로젝트 이름"
  type        = string
  default     = "cal-ml"
}

variable "environment" {
  description = "환경 이름(dev, test 등)"
  type        = string
  default     = "dev"
}

# ------------------------------
# 네트워크
# ------------------------------
variable "vpc_cidr" {
  description = "프로젝트 전용 VPC CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "GPU EC2가 위치할 Public Subnet CIDR"
  type        = string
  default     = "10.20.1.0/24"
}

# ------------------------------
# EC2 / Storage
# ------------------------------
variable "instance_type" {
  description = "GPU 학습용 EC2 유형. 기본 g6.2xlarge = NVIDIA L4 24GB"
  type        = string
  default     = "g6.2xlarge"
}

variable "root_volume_size" {
  description = "OS/기본 도구용 Root EBS(gp3) 용량, GiB"
  type        = number
  default     = 100
}

variable "data_volume_size" {
  description = "코드/Notebook/checkpoint용 Data EBS(gp3) 용량, GiB"
  type        = number
  default     = 300
}

variable "data_volume_iops" {
  description = "Data EBS gp3 IOPS"
  type        = number
  default     = 3000
}

variable "data_volume_throughput" {
  description = "Data EBS gp3 throughput(MiB/s)"
  type        = number
  default     = 125
}

# ------------------------------
# S3
# ------------------------------
variable "s3_force_destroy" {
  description = "true면 terraform destroy 시 Version을 포함한 S3 객체도 함께 삭제. 기본 false는 학습 데이터 보호"
  type        = bool
  default     = false
}

# ------------------------------
# 접속 방식
# ------------------------------
variable "enable_ssh" {
  description = "SSH 22번 포트를 열지 여부. 기본 false, SSM 접속 권장"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "SSH 사용 시 허용할 공인 IP CIDR"
  type        = string
  default     = "127.0.0.1/32"
}

variable "key_name" {
  description = "기존 EC2 Key Pair 이름. enable_ssh=true일 때만 필요"
  type        = string
  default     = null
  nullable    = true
}

# ------------------------------
# 개발환경 Bootstrap
# ------------------------------
variable "jupyter_port" {
  description = "EC2 내부 JupyterLab 포트. 외부 공개 없이 SSM tunnel로 접근"
  type        = number
  default     = 8888
}

variable "install_ml_packages" {
  description = "requirements.txt의 ML/Python 패키지를 자동 설치할지 여부"
  type        = bool
  default     = true
}

variable "bootstrap_timeout_seconds" {
  description = "SSM bootstrap 최대 실행/대기 시간. torch 설치 등을 고려해 기본 2시간"
  type        = number
  default     = 7200

  validation {
    condition     = var.bootstrap_timeout_seconds >= 600 && var.bootstrap_timeout_seconds <= 28800
    error_message = "bootstrap_timeout_seconds는 600~28800초 사이로 지정하세요."
  }
}

# ------------------------------
# 비용 알림 (선택)
# ------------------------------
variable "budget_email" {
  description = "AWS Budget 알림 이메일. 빈 문자열이면 Budget 미생성"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "월 비용 알림 기준(USD)"
  type        = number
  default     = 250
}
