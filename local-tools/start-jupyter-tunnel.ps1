# Windows PowerShell에서 실행한다.
# 사전 요구사항: AWS CLI, Session Manager Plugin, Terraform
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

$InstanceId = terraform output -raw instance_id
$Region = terraform output -raw aws_region
$Port = terraform output -raw jupyter_port
$Parameters = "{`"portNumber`":[`"$Port`"],`"localPortNumber`":[`"$Port`"]}"

Write-Host "Jupyter tunnel: http://127.0.0.1:$Port/lab"
Write-Host "종료하려면 Ctrl+C를 누르세요."

aws ssm start-session `
  --target $InstanceId `
  --region $Region `
  --document-name AWS-StartPortForwardingSession `
  --parameters $Parameters
