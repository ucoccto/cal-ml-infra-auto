$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"

$InstanceId = terraform "-chdir=$InfraDir" output -raw instance_id
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($InstanceId)) {
    throw "Terraform에서 instance_id를 가져오지 못했습니다."
}

$Region = terraform "-chdir=$InfraDir" output -raw aws_region
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Region)) {
    throw "Terraform에서 aws_region을 가져오지 못했습니다."
}

$Port = terraform "-chdir=$InfraDir" output -raw jupyter_port
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Port)) {
    throw "Terraform에서 jupyter_port를 가져오지 못했습니다."
}

$Ping = aws ssm describe-instance-information `
    --region $Region `
    --query "InstanceInformationList[?InstanceId=='$InstanceId'].PingStatus | [0]" `
    --output text

if ($LASTEXITCODE -ne 0) {
    throw "SSM 상태 조회에 실패했습니다."
}

if ($Ping -ne "Online") {
    throw "SSM 상태가 Online이 아닙니다: $Ping"
}

# Windows PowerShell 5.x에서 native executable에 JSON 문자열을 직접 넘기면
# 큰따옴표가 제거될 수 있으므로, CLI input JSON 파일을 사용한다.
$SessionInput = @{
    Target       = $InstanceId
    DocumentName = "AWS-StartPortForwardingSession"
    Parameters   = @{
        portNumber      = @("$Port")
        localPortNumber = @("$Port")
    }
}

$TempFile = Join-Path $env:TEMP "cal-ml-ssm-session-$PID.json"

try {
    $SessionInput |
        ConvertTo-Json -Depth 5 -Compress |
        Set-Content -Path $TempFile -Encoding ASCII

    # AWS CLI file:// 형식에서 Windows 경로 호환성을 높이기 위해 / 로 변환한다.
    $AwsTempPath = (Resolve-Path $TempFile).Path -replace "\\", "/"
    $CliInput = "file://$AwsTempPath"

    Write-Host ""
    Write-Host "Jupyter tunnel: http://127.0.0.1:$Port/lab"
    Write-Host "종료: Ctrl+C"
    Write-Host ""

    aws ssm start-session `
        --region $Region `
        --cli-input-json $CliInput

    if ($LASTEXITCODE -ne 0) {
        throw "SSM Jupyter 포트포워딩 세션 시작에 실패했습니다."
    }
}
finally {
    Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
}
