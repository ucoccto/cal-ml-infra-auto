# ============================================================================
# EC2 개발환경 자동 구성
#
# EC2 user_data는 SSM Agent 연결만 담당한다.
# 실제 bootstrap shell은 Terraform이 S3에 렌더링/업로드하고,
# State Manager의 AWS-RunRemoteScript가 EBS attach 이후 내려받아 실행한다.
#
# 이 구조의 목적:
# 1) Data EBS가 실제 attach된 뒤 설치 시작
# 2) 긴 shell script를 SSM parameter에 직접 삽입하지 않음
# 3) Terraform apply가 Association Success를 기다려 설치 실패를 숨기지 않음
# 4) 동일 태그의 새 EC2가 SSM Managed Node가 되면 Association 자동 적용
# ============================================================================
resource "aws_ssm_association" "bootstrap" {
  name             = "AWS-RunRemoteScript"
  association_name = "${var.project_name}-${var.environment}-bootstrap"

  # AWS 공식 AWS-RunRemoteScript 문서가 private S3 object를 내려받아 실행한다.
  # bootstrap_hash를 commandLine comment에 포함시켜 script 내용이 바뀌면
  # Association parameter도 변경되고 즉시 다시 실행되게 한다.
  parameters = {
    sourceType = "S3"
    sourceInfo = jsonencode({
      path = "https://${aws_s3_bucket.data.bucket}.s3.${var.aws_region}.amazonaws.com/${local.bootstrap_object_key}"
    })
    commandLine      = "bash bootstrap.sh # bootstrap_hash=${substr(sha256(local.bootstrap_script), 0, 16)}"
    executionTimeout = tostring(var.bootstrap_timeout_seconds)
  }

  # 태그 Target은 새 EC2가 SSM Managed Node로 등록되면 자동 적용된다.
  targets {
    key    = "tag:BootstrapTarget"
    values = [local.bootstrap_target]
  }

  max_concurrency = "1"
  max_errors      = "0"

  # pip/torch 설치가 오래 걸릴 수 있으므로 충분히 기다린다.
  wait_for_success_timeout_seconds = var.bootstrap_timeout_seconds + 300

  # 최초 apply에서는 Data EBS attach, bootstrap/project 파일 업로드 및 IAM
  # 권한 연결까지 끝난 뒤 Association을 만든다.
  depends_on = [
    aws_volume_attachment.data,
    aws_s3_object.bootstrap_script,
    aws_s3_object.project_template,
    aws_iam_role_policy_attachment.s3_access,
    aws_iam_role_policy_attachment.ssm
  ]
}
