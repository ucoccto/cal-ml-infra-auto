# Terraform apply 후 AWS/Bootstrap 핵심 상태를 검증한다.
# Windows PowerShell 5.1에서도 한글이 깨지지 않도록 UTF-8 출력으로 맞춘다.
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RootDir = Split-Path -Parent $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"

function TfOutput([string]$Name) {
    return (terraform "-chdir=$InfraDir" output -raw $Name).Trim()
}

$InstanceId = TfOutput "instance_id"
$Region = TfOutput "aws_region"
$VolumeId = TfOutput "data_ebs_volume_id"
$ProfileName = TfOutput "iam_instance_profile_name"
$AssociationId = TfOutput "bootstrap_association_id"

$Failed = $false
function Check([string]$Label, [bool]$Ok, [string]$Detail) {
    if ($Ok) {
        Write-Host "[OK]   $Label - $Detail"
    } else {
        Write-Host "[FAIL] $Label - $Detail"
        $script:Failed = $true
    }
}

# 1. EC2
$State = (aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].State.Name" --output text).Trim()
Check "EC2" ($State -eq "running") "state=$State id=$InstanceId"

# 2. IAM Instance Profile
$ProfileArn = (aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" --output text).Trim()
Check "IAM Instance Profile" ($ProfileArn -like "*$ProfileName") "arn=$ProfileArn"

# 3. SSM Managed Node
$Ping = (aws ssm describe-instance-information --region $Region --query "InstanceInformationList[?InstanceId=='$InstanceId'].PingStatus | [0]" --output text).Trim()
Check "SSM" ($Ping -eq "Online") "PingStatus=$Ping"

# 4. Data EBS Attachment
$AttachedInstance = (aws ec2 describe-volumes --volume-ids $VolumeId --region $Region --query "Volumes[0].Attachments[0].InstanceId" --output text).Trim()
$AttachState = (aws ec2 describe-volumes --volume-ids $VolumeId --region $Region --query "Volumes[0].Attachments[0].State" --output text).Trim()
Check "Data EBS" (($AttachedInstance -eq $InstanceId) -and ($AttachState -eq "attached")) "volume=$VolumeId state=$AttachState instance=$AttachedInstance"

# 5. SSM State Manager Association
# Targets 기반 Association을 association-id로 조회하면 Status 객체가 생략될 수 있다.
# 이 경우 실제 집계 상태는 AssociationDescription.Overview.Status에 있다.
$AssociationRaw = aws ssm describe-association --association-id $AssociationId --region $Region --output json
$Association = $AssociationRaw | ConvertFrom-Json
$Description = $Association.AssociationDescription

$AssociationStatus = $Description.Overview.Status
$DetailedStatus = $Description.Overview.DetailedStatus

# 구형/InstanceId 직접 Association 형식에 대한 fallback
if ([string]::IsNullOrWhiteSpace([string]$AssociationStatus)) {
    $AssociationStatus = $Description.Status.Name
}

if ([string]::IsNullOrWhiteSpace([string]$AssociationStatus)) {
    $AssociationStatus = "Unknown"
}

if ([string]::IsNullOrWhiteSpace([string]$DetailedStatus)) {
    $DetailedStatus = "-"
}

Check "Bootstrap Association" ($AssociationStatus -eq "Success") "status=$AssociationStatus detail=$DetailedStatus id=$AssociationId"

if ($Failed) {
    Write-Host ""
    Write-Host "환경 검증 실패. 아래 Association 상세 상태를 확인하세요."
    aws ssm describe-association --association-id $AssociationId --region $Region `
        --query "AssociationDescription.{Status:Overview.Status,DetailedStatus:Overview.DetailedStatus,Counts:Overview.AssociationStatusAggregatedCount,LastExecutionDate:LastExecutionDate,LastSuccessfulExecutionDate:LastSuccessfulExecutionDate}" `
        --output json | Out-Host
    Write-Host ""
    Write-Host "추가 절차는 TROUBLESHOOTING.md를 확인하세요."
    exit 1
}

Write-Host ""
Write-Host "모든 AWS 연결 상태가 정상입니다."
Write-Host "다음 단계: .\local-tools\start-jupyter-tunnel.ps1"
