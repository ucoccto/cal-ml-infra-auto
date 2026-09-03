$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"
$InstanceId = terraform "-chdir=$InfraDir" output -raw instance_id
$Region = terraform "-chdir=$InfraDir" output -raw aws_region

$State = aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].State.Name" --output text
if ($State -eq "running") {
    aws ec2 stop-instances --instance-ids $InstanceId --region $Region | Out-Host
    Write-Host "Stop requested: $InstanceId"
} else {
    Write-Host "현재 상태: $State (stop 요청 생략)"
}
