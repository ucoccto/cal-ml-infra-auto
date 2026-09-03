locals {
  # Terraform 구성은 infra/에 있고, 코드/템플릿은 프로젝트 루트에 있다.
  # 모든 파일 경로를 이 기준으로 통일한다.
  project_root         = abspath("${path.module}/..")
  project_template_dir = "${local.project_root}/project-template"
  bootstrap_template   = "${local.project_root}/templates/bootstrap.sh.tftpl"
  user_data_template   = "${local.project_root}/templates/user_data.sh.tftpl"

  # Bucket 이름은 전 세계에서 유일해야 하므로 계정 ID와 리전을 포함한다.
  bucket_name = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  # SSM State Manager가 EC2를 태그로 안정적으로 찾기 위한 값이다.
  bootstrap_target     = "${var.project_name}-${var.environment}-gpu"
  bootstrap_object_key = "bootstrap/runtime/bootstrap.sh"

  # project-template 아래의 실제 파일만 S3 bootstrap 영역으로 업로드한다.
  project_template_files = fileset(local.project_template_dir, "**")

  # 전체 개발환경 설치 스크립트는 Terraform에서 변수를 렌더링한 뒤
  # AWS-RunShellScript State Manager Association의 commands로 전달한다.
  bootstrap_script = templatefile(local.bootstrap_template, {
    project_name        = var.project_name
    s3_bucket           = aws_s3_bucket.data.bucket
    data_volume_id      = aws_ebs_volume.data.id
    jupyter_port        = var.jupyter_port
    install_ml_packages = var.install_ml_packages
    aws_region          = var.aws_region
  })
}
