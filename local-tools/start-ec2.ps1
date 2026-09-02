# 학습을 시작할 때 GPU EC2를 Start한다.
$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir
$InstanceId = terraform output -raw instance_id
$Region = terraform output -raw aws_region
aws ec2 start-instances --instance-ids $InstanceId --region $Region
aws ec2 wait instance-running --instance-ids $InstanceId --region $Region
Write-Host "EC2 is running: $InstanceId"
