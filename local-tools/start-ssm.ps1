# Windows PowerShell에서 EC2 shell에 접속한다.
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

$InstanceId = terraform output -raw instance_id
$Region = terraform output -raw aws_region
aws ssm start-session --target $InstanceId --region $Region
