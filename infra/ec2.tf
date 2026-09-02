# AWS가 공개한 SSM Public Parameter에서 최신 Ubuntu 24.04 GPU DLAMI의 AMI ID를 조회한다.
# 특정 AMI ID를 코드에 하드코딩하지 않으므로 새 DLAMI 릴리스에도 대응하기 쉽다.
data "aws_ssm_parameter" "dlami_gpu" {
  name = "/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-24.04/latest/ami-id"
}

resource "aws_instance" "ml" {
  ami           = data.aws_ssm_parameter.dlami_gpu.value
  instance_type = var.instance_type

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ml.id]
  iam_instance_profile   = aws_iam_instance_profile.ml_ec2.name

  # SSH가 비활성화된 기본 구성에서는 Key Pair가 필요하지 않다.
  key_name = var.enable_ssh ? var.key_name : null

  # NAT Gateway 비용을 쓰지 않고 패키지 다운로드/SSM 접속을 하기 위해 Public IP를 사용한다.
  # 보안그룹 Inbound는 기본 0개이므로 인터넷에서 Jupyter/SSH로 직접 접근할 수 없다.
  associate_public_ip_address = true

  # OS/시스템 패키지용 Root EBS다.
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

  # EC2 최초 부팅에서 개발환경까지 자동 구성한다.
  # - Data EBS /workspace 마운트
  # - 프로젝트 Template S3 다운로드
  # - Python venv + requirements 설치
  # - JupyterLab systemd 서비스 생성
  # - GPU/환경 점검
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    project_name        = var.project_name
    s3_bucket           = aws_s3_bucket.data.bucket
    data_volume_id      = aws_ebs_volume.data.id
    jupyter_port        = var.jupyter_port
    install_ml_packages = var.install_ml_packages
    aws_region          = var.aws_region
  })

  lifecycle {
    precondition {
      condition     = !var.enable_ssh || var.key_name != null
      error_message = "enable_ssh=true이면 key_name에 기존 EC2 Key Pair 이름을 지정해야 합니다."
    }

    precondition {
      condition     = !var.enable_ssh || var.ssh_allowed_cidr != "0.0.0.0/0"
      error_message = "교육용 GPU 서버의 SSH를 0.0.0.0/0에 공개하지 마세요. 자신의 공인 IP/32를 사용하세요."
    }
  }

  # EC2 생성 전에 Bootstrap 프로젝트 파일을 S3에 업로드해야 한다.
  depends_on = [
    aws_s3_object.project_template,
    aws_iam_role_policy_attachment.s3_access,
    aws_iam_role_policy_attachment.ssm
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-gpu"
  }
}
