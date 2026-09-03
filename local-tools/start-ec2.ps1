$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"

$InstanceId = terraform "-chdir=$InfraDir" output -raw instance_id
$Region = terraform "-chdir=$InfraDir" output -raw aws_region

$State = aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].State.Name" --output text
if ($State -eq "stopped") {
    aws ec2 start-instances --instance-ids $InstanceId --region $Region | Out-Host
} elseif ($State -ne "running") {
    throw "EC2 상태가 start 가능한 상태가 아닙니다: $State"
}

aws ec2 wait instance-running --instance-ids $InstanceId --region $Region
aws ec2 wait instance-status-ok --instance-ids $InstanceId --region $Region

Write-Host "SSM Online 대기 중..."
$Online = $false
for ($i = 1; $i -le 60; $i++) {
    $Ping = aws ssm describe-instance-information --region $Region --query "InstanceInformationList[?InstanceId=='$InstanceId'].PingStatus | [0]" --output text
    if ($Ping -eq "Online") {
        $Online = $true
        break
    }
    Start-Sleep -Seconds 5
}

if (-not $Online) {
    throw "EC2는 running이지만 SSM이 Online이 되지 않았습니다. verify-environment.ps1로 확인하세요."
}

Write-Host "EC2 + SSM ready: $InstanceId"
