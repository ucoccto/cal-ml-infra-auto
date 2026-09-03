# AWS가 공개한 SSM Public Parameter에서 최신 Ubuntu 24.04 GPU DLAMI AMI ID를 조회한다.
# 최초 생성 시 최신 AMI를 사용하되, 이후 AWS가 latest 값을 갱신했다고 해서
# 기존 학습 서버를 의도치 않게 교체하지 않도록 lifecycle에서 ami 변경은 무시한다.
data "aws_ssm_parameter" "dlami_gpu" {
  name = "/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-24.04/latest/ami-id"
}

resource "aws_instance" "ml" {
  ami           = data.aws_ssm_parameter.dlami_gpu.value
  instance_type = var.instance_type

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ml.id]

  # SSM/S3 권한이 포함된 Instance Profile을 EC2 시작 시점부터 연결한다.
  iam_instance_profile = aws_iam_instance_profile.ml_ec2.name

  # SSH가 비활성화된 기본 구성에서는 Key Pair가 필요하지 않다.
  key_name = var.enable_ssh ? var.key_name : null

  # NAT Gateway 비용 없이 인터넷/SSM/S3/Python package endpoint에 접근한다.
  # Security Group inbound는 기본 0개라 Public IP가 있어도 외부에서 직접 접근할 수 없다.
  associate_public_ip_address = true

  # OS에서 shutdown 명령이 실행되더라도 terminate가 아니라 stop 되도록 명시한다.
  instance_initiated_shutdown_behavior = "stop"

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-root"
    }
  }

  # IMDSv2만 허용한다.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # user_data에서는 SSM Agent만 최대한 빨리 Online으로 만든다.
  # EBS mount / Python / Jupyter는 bootstrap.tf의 SSM Association이 담당한다.
  user_data                   = file(local.user_data_template)
  user_data_replace_on_change = false

  lifecycle {
    # AWS의 latest DLAMI Public Parameter가 갱신되어도 기존 EC2를 자동 교체하지 않는다.
    # EC2가 실제로 사라져 재생성될 때는 현재 latest AMI가 사용된다.
    ignore_changes = [ami]

    precondition {
      condition     = !var.enable_ssh || var.key_name != null
      error_message = "enable_ssh=true이면 key_name에 기존 EC2 Key Pair 이름을 지정해야 합니다."
    }

    precondition {
      condition     = !var.enable_ssh || var.ssh_allowed_cidr != "0.0.0.0/0"
      error_message = "교육용 GPU 서버의 SSH를 0.0.0.0/0에 공개하지 마세요. 자신의 공인 IP/32를 사용하세요."
    }
  }

  # EC2가 뜨기 전에 IAM 권한과 Public Route가 준비되도록 생성 순서를 명시한다.
  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.s3_access,
    aws_iam_role_policy_attachment.ssm
  ]

  tags = {
    Name            = "${var.project_name}-${var.environment}-gpu"
    BootstrapTarget = local.bootstrap_target
  }
}
