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
  description = "GPU 학습용 EC2 유형. 기본값은 NVIDIA L4 24GB를 사용하는 g6.2xlarge"
  type        = string
  default     = "g6.2xlarge"
}

variable "root_volume_size" {
  description = "OS와 기본 도구가 저장되는 Root EBS(gp3) 용량, GiB"
  type        = number
  default     = 100
}

variable "data_volume_size" {
  description = "프로젝트 코드/노트북/checkpoint를 저장하는 Data EBS(gp3) 용량, GiB"
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
# 접속 방식
# ------------------------------
variable "enable_ssh" {
  description = "SSH 22번 포트를 열지 여부. 기본은 false이며 SSM 접속을 권장"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "SSH를 사용할 때 허용할 공인 IP CIDR. 0.0.0.0/0 사용 금지 권장"
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
  description = "EC2 내부 JupyterLab 포트. 외부 공개하지 않고 SSM tunnel로 접근"
  type        = number
  default     = 8888
}

variable "install_ml_packages" {
  description = "EC2 최초 부팅 시 requirements.txt의 ML/Python 패키지를 자동 설치할지 여부"
  type        = bool
  default     = true
}

# ------------------------------
# 비용 알림 (선택)
# ------------------------------
variable "budget_email" {
  description = "AWS Budget 알림을 받을 이메일. 빈 문자열이면 Budget 리소스를 만들지 않음"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "월 비용 알림 기준(USD). 30~40만원 예산이면 환율에 맞게 조정"
  type        = number
  default     = 250
}
