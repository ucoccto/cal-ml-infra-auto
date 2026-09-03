# CAL ML AWS 환경을 한 번에 초기화/검증/적용한다.
# Windows PowerShell에서 프로젝트 루트에서 실행:
#   .\deploy.ps1
$ErrorActionPreference = "Stop"

$RootDir = $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"

Write-Host "[1/5] AWS credentials 확인"
aws sts get-caller-identity | Out-Host

Write-Host "[2/5] Terraform init"
terraform "-chdir=$InfraDir" init

Write-Host "[3/5] Terraform fmt / validate"
terraform "-chdir=$InfraDir" fmt -recursive
terraform "-chdir=$InfraDir" validate

Write-Host "[4/5] Terraform plan"
$PlanFile = Join-Path $InfraDir "cal-ml.tfplan"
terraform "-chdir=$InfraDir" plan -out=$PlanFile

$Answer = Read-Host "위 Plan을 적용할까요? (yes 입력)"
if ($Answer -ne "yes") {
    Write-Host "적용을 취소했습니다."
    exit 0
}

Write-Host "[5/5] Terraform apply"
terraform "-chdir=$InfraDir" apply $PlanFile

Remove-Item $PlanFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Terraform apply 완료. SSM bootstrap Association도 Success여야 apply가 완료됩니다."
Write-Host "다음 확인: .\local-tools\verify-environment.ps1"
