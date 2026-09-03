$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"
$InstanceId = terraform "-chdir=$InfraDir" output -raw instance_id
$Region = terraform "-chdir=$InfraDir" output -raw aws_region

$Ping = aws ssm describe-instance-information --region $Region --query "InstanceInformationList[?InstanceId=='$InstanceId'].PingStatus | [0]" --output text
if ($Ping -ne "Online") {
    throw "SSM 상태가 Online이 아닙니다: $Ping"
}

aws ssm start-session --target $InstanceId --region $Region
