# 프로젝트 전용 VPC를 생성한다.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# Public Subnet의 인터넷 통신을 위해 Internet Gateway를 연결한다.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# 단일 GPU 학습 서버이므로 우선 한 개 AZ의 Public Subnet만 사용한다.
# NAT Gateway를 제거해 불필요한 고정 비용을 피한다.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-a"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # 패키지 설치, S3/SSM API 접근을 위한 인터넷 경로다.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 기본 정책은 Inbound 0개다.
# Jupyter 8888 포트도 인터넷에 공개하지 않고 SSM Port Forwarding으로만 접속한다.
resource "aws_security_group" "ml" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "CAL ML GPU instance security group"
  vpc_id      = aws_vpc.main.id

  # SSH가 정말 필요한 경우에만 특정 IP에서 22번 포트를 허용한다.
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "Optional SSH from explicitly allowed CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.ssh_allowed_cidr]
    }
  }

  # OS 패키지/Python 패키지 다운로드 및 AWS API 호출을 위해 Outbound는 허용한다.
  egress {
    description = "Outbound internet and AWS API access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg"
  }
}
