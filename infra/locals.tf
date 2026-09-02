locals {
  # Bucket 이름은 전 세계에서 유일해야 하므로 계정 ID와 리전을 포함한다.
  bucket_name = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  # project-template 아래의 모든 파일을 S3 bootstrap 영역으로 업로드한다.
  # EC2 최초 부팅 시 이 파일들을 내려받아 /workspace/cal-project를 구성한다.
  project_template_files = fileset("${path.module}/project-template", "**")
}
