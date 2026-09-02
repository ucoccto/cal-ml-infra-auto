# 작업 종료 후 GPU compute 비용을 줄이기 위해 EC2를 Stop한다.
# Stop 전 Local NVMe의 필요한 결과를 EBS/S3로 저장해야 한다.
$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir
$InstanceId = terraform output -raw instance_id
$Region = terraform output -raw aws_region
aws ec2 stop-instances --instance-ids $InstanceId --region $Region
Write-Host "Stop requested: $InstanceId"
