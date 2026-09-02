output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

output "jupyter_port" {
  description = "JupyterLab local/remote port"
  value       = var.jupyter_port
}

output "instance_id" {
  description = "GPU EC2 Instance ID"
  value       = aws_instance.ml.id
}

output "instance_type" {
  description = "GPU EC2 Instance Type"
  value       = aws_instance.ml.instance_type
}

output "public_ip" {
  description = "EC2 Public IP. Stop/Start 후 변경될 수 있음"
  value       = aws_instance.ml.public_ip
}

output "s3_bucket" {
  description = "프로젝트 S3 Bucket"
  value       = aws_s3_bucket.data.bucket
}

output "data_ebs_volume_id" {
  description = "Persistent Data EBS Volume ID"
  value       = aws_ebs_volume.data.id
}

output "dlami_id" {
  description = "AWS Public SSM Parameter에서 조회한 최신 GPU DLAMI ID"
  value       = nonsensitive(data.aws_ssm_parameter.dlami_gpu.value)
}

output "ssm_session_command" {
  description = "터미널 접속용 SSM 명령"
  value       = "aws ssm start-session --target ${aws_instance.ml.id} --region ${var.aws_region}"
}

output "jupyter_tunnel_command_bash" {
  description = "Linux/macOS에서 Jupyter 8888 포트를 로컬로 포워딩하는 명령"
  value       = "aws ssm start-session --target ${aws_instance.ml.id} --region ${var.aws_region} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"${var.jupyter_port}\"],\"localPortNumber\":[\"${var.jupyter_port}\"]}'"
}

output "jupyter_url" {
  description = "SSM Port Forwarding 실행 후 브라우저에서 열 주소"
  value       = "http://127.0.0.1:${var.jupyter_port}/lab"
}

output "bootstrap_log_command" {
  description = "EC2 접속 후 Bootstrap 진행 로그 확인 명령"
  value       = "sudo tail -f /var/log/cal-bootstrap.log"
}
