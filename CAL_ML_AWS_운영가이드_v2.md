# CAL ML AWS 학습환경 운영 가이드

이 문서는 Terraform으로 구축한 **CAL 딥러닝 학습용 AWS 환경**을 실제로 운영하는 방법을 정리한 가이드입니다.

구성 대상은 다음과 같습니다.

- AWS EC2 GPU 인스턴스 (`g6.2xlarge`)
- NVIDIA L4 GPU
- Amazon S3
- Amazon EBS
- AWS Systems Manager (SSM)
- JupyterLab
- Python 가상환경
- PyTorch / CUDA
- Terraform

---

# 0. 최초 개발환경 구축 — Windows PC

이 절은 **새 Windows PC에서 처음부터 AWS/Terraform 개발환경을 준비하는 과정**입니다.

최초 한 번만 설정하면 이후에는 매번 다시 설치할 필요가 없습니다.

권장 환경:

```text
Windows 10/11 64-bit
PowerShell 5 이상
AWS CLI v2
Terraform CLI
AWS Session Manager Plugin
```

전체 순서:

```text
Terraform 설치
    ↓
AWS CLI 설치
    ↓
AWS 자격증명 설정
    ↓
AWS 접속 확인
    ↓
Session Manager Plugin 설치
    ↓
PowerShell 실행 정책 확인
    ↓
프로젝트 압축 해제
    ↓
terraform init / validate / plan
    ↓
deploy.ps1 실행
```

---

## 0.1 PowerShell 확인

PowerShell에서 다음 명령을 실행합니다.

```powershell
$PSVersionTable.PSVersion
```

Windows PowerShell 5.x 이상이면 사용할 수 있습니다.

프로젝트 작업은 가능하면 **PowerShell**을 기준으로 진행합니다.

---

## 0.2 Terraform 설치
( https://colab.research.google.com/drive/16zfEd2HbXLcsIzfDYRi7QwgdpZaQoKlp?usp=sharing )

Terraform은 AWS 인프라를 코드로 생성, 변경, 삭제하기 위한 IaC 도구입니다.

설치 후 다음 명령이 어느 경로에서든 실행될 수 있어야 합니다.

```powershell
terraform version
```

### 방법 A — Chocolatey를 사용하는 경우

이미 Chocolatey가 설치되어 있다면 관리자 PowerShell에서:

```powershell
choco install terraform -y
```

설치 확인:

```powershell
terraform version
```

### 방법 B — HashiCorp 공식 바이너리 설치

Chocolatey가 없다면 HashiCorp 공식 Terraform Windows AMD64 바이너리를 내려받아 사용할 수 있습니다.

다운로드한 ZIP의 `terraform.exe`를 예를 들어 다음 경로에 둡니다.

```text
C:\Tools\Terraform\terraform.exe
```

그 후:

```text
C:\Tools\Terraform
```

을 Windows `PATH` 환경 변수에 추가합니다.

새 PowerShell을 열고:

```powershell
terraform version
```

을 실행해 정상 출력되는지 확인합니다.

> Terraform 공식 설치 문서:  
> https://developer.hashicorp.com/terraform/install

---

## 0.3 AWS CLI v2 설치

Terraform이 AWS에 실제 리소스를 만들려면 로컬 PC에서 AWS 인증이 가능해야 합니다.

Windows PowerShell에서 AWS CLI v2를 설치합니다.

현재 사용자에 설치하는 AWS 공식 설치 방식:

```powershell
irm https://awscli.amazonaws.com/v2/install.ps1 | iex
```

설치 후 PowerShell을 새로 열고:

```powershell
aws --version
```

정상 예:

```text
aws-cli/2.x.x Python/... Windows/...
```

> AWS CLI 공식 설치 문서:  
> https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

---

## 0.4 AWS 자격증명 준비

Terraform과 AWS CLI는 AWS API를 호출할 수 있는 자격증명이 필요합니다.

교육/실습 계정에서 IAM User의 Access Key를 사용하는 경우 다음 정보가 필요합니다.

```text
AWS Access Key ID
AWS Secret Access Key
Default Region
```

이 프로젝트의 기본 Region:

```text
ap-northeast-2
```

즉 **서울 Region**입니다.

> 실제 운영환경에서는 장기 Access Key보다 AWS IAM Identity Center 등 단기 자격증명 방식을 권장합니다.  
> 교육용 IAM User를 사용하는 경우 Access Key를 외부에 노출하거나 Git에 저장하지 마세요.

---

## 0.5 AWS CLI 기본 Profile 설정

PowerShell에서:

```powershell
aws configure
```

순서대로 입력합니다.

```text
AWS Access Key ID [None]: <본인의 Access Key>
AWS Secret Access Key [None]: <본인의 Secret Access Key>
Default region name [None]: ap-northeast-2
Default output format [None]: json
```

설정 파일은 일반적으로 사용자 홈의 다음 위치에 저장됩니다.

```text
C:\Users\<사용자>\.aws\credentials
C:\Users\<사용자>\.aws\config
```

**이 파일을 GitHub 등에 업로드하지 않습니다.**

설정 확인:

```powershell
aws configure list
```

정상 예:

```text
profile      <not set>
access_key   ****************XXXX
secret_key   ****************XXXX
region       ap-northeast-2
```

---

## 0.6 AWS 인증 최종 확인

Terraform을 실행하기 전에 반드시 다음 명령을 먼저 확인합니다.

```powershell
aws sts get-caller-identity
```

정상이면 다음과 같은 정보가 출력됩니다.

```json
{
  "UserId": "...",
  "Account": "...",
  "Arn": "arn:aws:iam::...:user/..."
}
```

이 명령이 성공해야 Terraform 배포를 진행합니다.

### `InvalidClientTokenId`가 발생하는 경우

예:

```text
The security token included in the request is invalid.
```

다음부터 확인합니다.

```powershell
aws configure list
```

그리고 필요하면 다시:

```powershell
aws configure
```

확인 항목:

```text
Access Key가 현재 IAM User의 것인지
Secret Access Key가 올바른지
오래되거나 삭제된 Access Key가 아닌지
AWS_PROFILE 환경변수가 다른 Profile을 가리키지 않는지
```

현재 Profile 환경변수 확인:

```powershell
$env:AWS_PROFILE
```

필요하지 않은 잘못된 Profile이 설정되어 있다면 현재 PowerShell에서:

```powershell
Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
```

그 후 다시:

```powershell
aws sts get-caller-identity
```

로 확인합니다.

---

## 0.7 여러 AWS 계정을 사용하는 경우 — 선택 사항

한 PC에서 여러 AWS 계정을 사용하는 경우 Named Profile을 사용하는 것이 좋습니다.

예:

```powershell
aws configure --profile cal-ml
```

사용할 때:

```powershell
$env:AWS_PROFILE = "cal-ml"
```

확인:

```powershell
aws sts get-caller-identity --profile cal-ml
```

Terraform도 현재 `AWS_PROFILE` 환경변수를 사용할 수 있습니다.

현재 PowerShell 세션에서만 적용하려면:

```powershell
$env:AWS_PROFILE = "cal-ml"
```

작업을 끝낸 뒤 제거:

```powershell
Remove-Item Env:AWS_PROFILE
```

---

## 0.8 AWS Session Manager Plugin 설치

본 프로젝트는 일반 SSH 대신 **AWS Systems Manager Session Manager**를 사용합니다.

용도:

```text
로컬 PC
   ↓ SSM
EC2 Terminal 접속

로컬 127.0.0.1:8888
   ↓ SSM Port Forwarding
EC2 JupyterLab
```

AWS CLI만 설치되어 있다고 `aws ssm start-session`이 동작하는 것은 아닙니다.

Windows에는 **Session Manager Plugin**도 별도로 설치해야 합니다.

설치하지 않으면 다음 오류가 발생합니다.

```text
SessionManagerPlugin is not found
```

PowerShell에서 설치 파일 다운로드:

```powershell
Invoke-WebRequest `
  -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" `
  -OutFile "$env:TEMP\SessionManagerPluginSetup.exe"
```

관리자 권한으로 설치:

```powershell
Start-Process `
  "$env:TEMP\SessionManagerPluginSetup.exe" `
  -Verb RunAs `
  -Wait
```

설치 후 **PowerShell을 새로 열고**:

```powershell
session-manager-plugin --version
```

으로 확인합니다.

기본 설치 위치:

```text
C:\Program Files\Amazon\SessionManagerPlugin\bin\
```

명령을 찾지 못하는 경우 새 PowerShell을 다시 열거나 해당 경로가 `PATH`에 포함되어 있는지 확인합니다.

> AWS 공식 Session Manager Plugin 설치 문서:  
> https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-windows.html

---

## 0.9 필수 도구 전체 점검

새 PowerShell에서 다음 네 명령이 모두 정상이어야 합니다.

### Terraform

```powershell
terraform version
```

### AWS CLI

```powershell
aws --version
```

### AWS 인증

```powershell
aws sts get-caller-identity
```

### Session Manager Plugin

```powershell
session-manager-plugin --version
```

체크리스트:

```text
[ ] terraform version 정상
[ ] aws --version 정상
[ ] aws sts get-caller-identity 정상
[ ] Region = ap-northeast-2
[ ] session-manager-plugin --version 정상
```

---

## 0.10 프로젝트 압축 해제

예:

```text
C:\Users\<사용자>\Downloads\cal-ml-complete\
```

프로젝트 구조 예:

```text
cal-ml-complete/
├── deploy.ps1
├── infra/
├── project-template/
└── local-tools/
```

PowerShell에서 프로젝트 루트로 이동합니다.

```powershell
cd C:\Users\<사용자>\Downloads\cal-ml-complete
```

현재 위치 확인:

```powershell
Get-Location
```

파일 확인:

```powershell
Get-ChildItem
```

최소한 다음이 보여야 합니다.

```text
deploy.ps1
infra
project-template
local-tools
```

---

## 0.11 `terraform.tfvars` 준비

프로젝트에 예제 파일이 있다면:

```powershell
Copy-Item `
  .\infra\terraform.tfvars.example `
  .\infra\terraform.tfvars
```

그 후:

```text
infra\terraform.tfvars
```

를 열어 필요한 값을 확인합니다.

예:

```hcl
aws_region    = "ap-northeast-2"
environment   = "dev"
instance_type = "g6.2xlarge"
```

> AWS Access Key / Secret Access Key를 `terraform.tfvars`에 작성하지 않습니다.  
> AWS 자격증명은 AWS CLI Profile을 통해 사용합니다.

---

## 0.12 PowerShell Script 실행 허용

Windows 정책에 따라 다음 오류가 발생할 수 있습니다.

```text
이 시스템에서 스크립트를 실행할 수 없으므로
deploy.ps1 파일을 로드할 수 없습니다.
```

이 경우 **현재 PowerShell 창에서만** 임시 허용합니다.

```powershell
Set-ExecutionPolicy `
  -Scope Process `
  -ExecutionPolicy Bypass
```

`Scope Process`이므로 현재 PowerShell을 닫으면 원래 정책으로 돌아갑니다.

다운로드 파일 차단이 남아 있는 경우 프로젝트 루트에서:

```powershell
Get-ChildItem -Recurse -File | Unblock-File
```

를 사용할 수 있습니다.

---

## 0.13 Terraform 초기화

프로젝트 루트에서:

```powershell
terraform -chdir=infra init
```

이 명령은:

```text
Terraform Backend 초기화
AWS Provider 다운로드
Provider Plugin 준비
```

를 수행합니다.

정상적으로 완료되면:

```text
Terraform has been successfully initialized!
```

와 유사한 메시지가 출력됩니다.

---

## 0.14 Terraform 코드 포맷 및 검증

포맷:

```powershell
terraform -chdir=infra fmt
```

구문 검증:

```powershell
terraform -chdir=infra validate
```

정상:

```text
Success! The configuration is valid.
```

---

## 0.15 Terraform Plan 확인

실제 AWS 리소스를 만들기 전에:

```powershell
terraform -chdir=infra plan
```

을 실행합니다.

여기에서 생성 예정인 주요 리소스를 확인합니다.

```text
VPC
Subnet
Internet Gateway
Route Table
Security Group
S3 Bucket
IAM Role
IAM Instance Profile
EBS
EC2 GPU
SSM Association
```

오류 없이 Plan이 생성되어야 합니다.

---

## 0.16 권장 방식 — `deploy.ps1`로 최초 배포

개별 Terraform 명령을 직접 실행할 수도 있지만, 이 프로젝트는 다음 스크립트 사용을 권장합니다.

```powershell
.\deploy.ps1
```

스크립트에서는 전체적으로 다음 흐름을 수행합니다.

```text
AWS 인증 확인
    ↓
terraform init
    ↓
terraform fmt
    ↓
terraform validate
    ↓
terraform plan
    ↓
terraform apply
    ↓
SSM Bootstrap
    ↓
학습환경 구성 완료
```

배포 중 Terraform 확인 질문이 나오면 내용을 검토한 뒤:

```text
yes
```

를 입력합니다.

---

## 0.17 최초 구축 완료 후 확인

Terraform 출력:

```powershell
terraform -chdir=infra output
```

주요 값 예:

```text
instance_id
instance_type
data_ebs_volume_id
s3_bucket
aws_region
jupyter_port
```

그다음 전체 환경 검증:

```powershell
.\local-tools\verify-environment.ps1
```

최종 목표:

```text
[OK] EC2
[OK] IAM Instance Profile
[OK] SSM
[OK] Data EBS
[OK] Bootstrap Association
```

이 단계까지 완료되면 **최초 개발환경 구축은 끝**입니다.

이후에는 본 문서의 Jupyter 접속 및 GPU 학습 운영 절차를 따릅니다.

---

## 0.18 최초 구축 단계 핵심 요약

```text
[로컬 PC 최초 1회]

1. Terraform 설치
2. AWS CLI v2 설치
3. aws configure
4. aws sts get-caller-identity
5. Session Manager Plugin 설치
6. terraform.tfvars 확인
7. PowerShell 실행 정책 임시 허용
8. deploy.ps1
9. verify-environment.ps1


[이후 일상 사용]

EC2 Start
   ↓
verify-environment.ps1
   ↓
start-jupyter-tunnel.ps1
   ↓
Jupyter / GPU 학습
   ↓
결과 및 Checkpoint 저장
   ↓
EC2 Stop
```

---

# 1. 전체 아키텍처

```text
로컬 Windows PC
    │
    │ AWS CLI + Session Manager Plugin
    │
    ▼
AWS Systems Manager (SSM)
    │
    ├── EC2 Session 접속
    └── Jupyter 8888 Port Forwarding
            │
            ▼
       EC2 g6.2xlarge
       NVIDIA L4 GPU
            │
            ├── /workspace  → EBS
            │      ├── cal-project
            │      ├── datasets
            │      ├── checkpoints
            │      └── outputs
            │
            └── 로컬 NVMe
                   └── 임시 Cache 용도

S3
├── raw/
├── processed/
├── datasets/
├── checkpoints/
├── outputs/
└── bootstrap/
```

각 저장소의 역할은 다음과 같습니다.

| 구분 | 용도 |
|---|---|
| EC2 | GPU 연산 및 Jupyter 실행 |
| EBS `/workspace` | 실제 학습 데이터, 코드, 체크포인트, 결과 저장 |
| S3 | 원본 데이터 및 결과의 장기 보관 |
| Instance Store / NVMe | 임시 캐시 및 고속 임시 작업 |
| SSM | SSH 없이 EC2 접속 및 Port Forwarding |
| Terraform | AWS 인프라 생성/변경/삭제 |

> 중요한 데이터는 **EBS 또는 S3에 저장**합니다.  
> Instance Store/NVMe 영역은 EC2 Stop/Terminate 등의 상황에서 데이터가 유지되지 않을 수 있으므로 임시 캐시 용도로만 사용합니다.

---

# 2. 프로젝트 기본 구조

예시:

```text
cal-ml-complete/
├── deploy.ps1
├── infra/
│   ├── main.tf
│   ├── ec2.tf
│   ├── ebs.tf
│   ├── iam.tf
│   ├── network.tf
│   ├── s3.tf
│   ├── ssm.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── terraform.tfvars
│
├── project-template/
│   ├── requirements.txt
│   ├── notebooks/
│   └── scripts/
│
└── local-tools/
    ├── verify-environment.ps1
    └── start-jupyter-tunnel.ps1
```

Terraform 관련 명령은 프로젝트 루트에서 다음 형식으로 실행합니다.

```powershell
terraform -chdir=infra <command>
```

예:

```powershell
terraform -chdir=infra plan
terraform -chdir=infra apply
terraform -chdir=infra output
```

---

# 3. 최초 인프라 생성

Windows PowerShell에서 프로젝트 루트로 이동합니다.

```powershell
cd C:\path\to\cal-ml-complete
```

PowerShell 스크립트 실행이 차단되는 경우 현재 PowerShell 창에서만 임시 허용합니다.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

그다음:

```powershell
.\deploy.ps1
```

배포 과정에서는 일반적으로 다음 작업이 수행됩니다.

```text
AWS 인증 확인
    ↓
terraform init
    ↓
terraform fmt
    ↓
terraform validate
    ↓
terraform plan
    ↓
terraform apply
    ↓
VPC / IAM / S3 / EBS / EC2 생성
    ↓
SSM 연결
    ↓
Bootstrap 실행
    ↓
Jupyter / Python / PyTorch 환경 구성
```

---

# 4. 인프라 구축 완료 후 검증

프로젝트 루트에서:

```powershell
.\local-tools\verify-environment.ps1
```

정상적인 경우 다음 항목들이 모두 `[OK]`가 되어야 합니다.

```text
[OK] EC2
[OK] IAM Instance Profile
[OK] SSM
[OK] Data EBS
[OK] Bootstrap Association
```

예:

```text
[OK]   EC2 - state=running
[OK]   IAM Instance Profile
[OK]   SSM - PingStatus=Online
[OK]   Data EBS - state=attached
[OK]   Bootstrap Association - status=Success
```

이 단계까지 통과하면 AWS 학습환경의 기본 구성은 완료된 것입니다.

---

# 5. 로컬 Windows PC에 필요한 프로그램

SSM과 Jupyter Port Forwarding을 사용하려면 로컬 PC에 다음 프로그램이 필요합니다.

## 5.1 AWS CLI 확인

```powershell
aws --version
```

예:

```text
aws-cli/2.x.x
```

설치 후 AWS 인증이 정상인지 확인합니다.

```powershell
aws sts get-caller-identity
```

정상이면 현재 AWS Account와 IAM User/Role 정보가 출력됩니다.

---

# 6. Session Manager Plugin 설치

`aws ssm start-session`을 사용하려면 **AWS Session Manager Plugin**이 로컬 PC에 설치되어 있어야 합니다.

설치되지 않은 경우 다음 오류가 발생합니다.

```text
SessionManagerPlugin is not found
```

Windows PowerShell에서 설치 파일을 내려받습니다.

```powershell
Invoke-WebRequest `
  -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" `
  -OutFile "$env:TEMP\SessionManagerPluginSetup.exe"
```

관리자 권한으로 설치합니다.

```powershell
Start-Process `
  "$env:TEMP\SessionManagerPluginSetup.exe" `
  -Verb RunAs `
  -Wait
```

설치 후 PowerShell을 새로 열고 확인합니다.

```powershell
session-manager-plugin --version
```

버전이 정상적으로 출력되면 준비 완료입니다.

---

# 7. SSM으로 EC2 접속

현재 EC2 Instance ID를 확인합니다.

```powershell
terraform -chdir=infra output -raw instance_id
```

리전:

```powershell
terraform -chdir=infra output -raw aws_region
```

SSM으로 직접 터미널 접속:

```powershell
aws ssm start-session `
  --target $(terraform -chdir=infra output -raw instance_id) `
  --region $(terraform -chdir=infra output -raw aws_region)
```

SSM을 사용하기 때문에 일반적인 SSH 접속용 Key Pair를 반드시 사용할 필요는 없습니다.

---

# 8. JupyterLab 접속

프로젝트 루트에서:

```powershell
.\local-tools\start-jupyter-tunnel.ps1
```

정상적인 경우:

```text
Jupyter tunnel: http://127.0.0.1:8888/lab

Starting session with SessionId: ...
Port 8888 opened for sessionId ...
Waiting for connections...
```

이 PowerShell 창은 **Jupyter를 사용하는 동안 닫지 않습니다.**

브라우저에서 다음 주소를 엽니다.

```text
http://127.0.0.1:8888/lab
```

접속 구조:

```text
Browser
   │
   │ 127.0.0.1:8888
   ▼
SSM Port Forwarding
   ▼
EC2 127.0.0.1:8888
   ▼
JupyterLab
```

> Security Group에 8888 포트를 외부 공개할 필요가 없습니다.

---

# 9. GPU 확인

JupyterLab의 Terminal 또는 SSM 접속 터미널에서:

```bash
nvidia-smi
```

현재 구성에서는 정상적으로 다음 GPU가 보여야 합니다.

```text
NVIDIA L4
```

예:

```text
GPU Name      : NVIDIA L4
GPU Memory    : 약 23 GB
Driver        : 정상
CUDA Support  : 정상
```

---

# 10. PyTorch CUDA 확인

프로젝트 가상환경으로 이동합니다.

```bash
cd /workspace/cal-project
source /workspace/venv/bin/activate
```

PyTorch 확인:

```bash
python -c "import torch; print('PyTorch:', torch.__version__); print('CUDA available:', torch.cuda.is_available()); print('PyTorch CUDA:', torch.version.cuda); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')"
```

정상 예:

```text
PyTorch: 2.x.x
CUDA available: True
PyTorch CUDA: 12.x
GPU: NVIDIA L4
```

핵심은 다음 값입니다.

```text
CUDA available: True
```

---

# 11. 프로젝트 GPU 테스트

프로젝트에 포함된 GPU 확인 스크립트:

```bash
cd /workspace/cal-project
source /workspace/venv/bin/activate

python scripts/gpu_check.py
```

실제 GPU 연산 smoke test:

```bash
python scripts/smoke_train.py
```

정상적인 경우 다음 단계까지 확인된 것입니다.

```text
EC2 GPU 인식
    ↓
NVIDIA Driver 정상
    ↓
PyTorch 정상
    ↓
CUDA 사용 가능
    ↓
실제 GPU Tensor 연산 정상
```

---

# 12. S3 사용

S3 Bucket 이름 확인:

```powershell
terraform -chdir=infra output -raw s3_bucket
```

예상 구조:

```text
s3://<bucket>/

raw/
├── stl/
│
processed/
├── voxel/
├── projection/
├── gradient/
├── curvature/
├── levelset/
└── geometry/

datasets/
├── train/
├── validation/
└── test/

checkpoints/
outputs/
bootstrap/
```

파일 업로드 예:

```bash
aws s3 cp sample.stl \
  s3://<bucket-name>/raw/stl/sample.stl
```

디렉터리 전체 업로드:

```bash
aws s3 sync ./datasets \
  s3://<bucket-name>/datasets/
```

S3 → EC2 EBS 다운로드:

```bash
aws s3 sync \
  s3://<bucket-name>/datasets/ \
  /workspace/datasets/
```

---

# 13. 학습 데이터 저장 원칙

권장 구조:

```text
/workspace/
├── cal-project/
├── datasets/
├── checkpoints/
├── outputs/
└── cache/
```

용도:

| 경로 | 용도 |
|---|---|
| `/workspace/cal-project` | 프로젝트 코드 |
| `/workspace/datasets` | 학습 데이터 |
| `/workspace/checkpoints` | 모델 checkpoint |
| `/workspace/outputs` | 최종 결과 |
| `/workspace/cache` | 캐시 |

중요 데이터는 학습 완료 후 S3에도 동기화하는 것을 권장합니다.

예:

```bash
aws s3 sync \
  /workspace/checkpoints/ \
  s3://<bucket-name>/checkpoints/
```

결과:

```bash
aws s3 sync \
  /workspace/outputs/ \
  s3://<bucket-name>/outputs/
```

---

# 14. 학습을 시작할 때

평소 EC2를 Stop 상태로 두었다면 학습 시작 전에 Start 합니다.

Instance ID 확인:

```powershell
$INSTANCE_ID = terraform -chdir=infra output -raw instance_id
```

EC2 Start:

```powershell
aws ec2 start-instances `
  --instance-ids $INSTANCE_ID `
  --region ap-northeast-2
```

상태 확인:

```powershell
aws ec2 describe-instances `
  --instance-ids $INSTANCE_ID `
  --region ap-northeast-2 `
  --query "Reservations[0].Instances[0].State.Name" `
  --output text
```

정상:

```text
running
```

그다음 환경 검증:

```powershell
.\local-tools\verify-environment.ps1
```

SSM이 `Online`이 된 후:

```powershell
.\local-tools\start-jupyter-tunnel.ps1
```

브라우저:

```text
http://127.0.0.1:8888/lab
```

학습 시작 전 권장 확인:

```bash
nvidia-smi

cd /workspace/cal-project
source /workspace/venv/bin/activate

python scripts/gpu_check.py
```

---

# 15. 학습 중 권장 운영

학습 중에는 다음 항목을 확인합니다.

GPU 사용률:

```bash
watch -n 2 nvidia-smi
```

디스크:

```bash
df -h
```

EBS mount:

```bash
findmnt /workspace
```

메모리:

```bash
free -h
```

프로세스:

```bash
ps aux
```

중요한 학습은 주기적으로 checkpoint를 저장합니다.

예:

```text
/workspace/checkpoints/
```

그리고 중요한 checkpoint는 S3에 업로드합니다.

```bash
aws s3 sync \
  /workspace/checkpoints/ \
  s3://<bucket-name>/checkpoints/
```

---

# 16. 학습을 종료할 때

EC2를 바로 Stop하기 전에 다음 순서를 권장합니다.

## 16.1 실행 중인 학습 종료 확인

```bash
nvidia-smi
```

GPU에서 학습 프로세스가 남아있지 않은지 확인합니다.

---

## 16.2 checkpoint 저장

```text
/workspace/checkpoints/
```

---

## 16.3 중요 결과 S3 백업

```bash
aws s3 sync \
  /workspace/checkpoints/ \
  s3://<bucket-name>/checkpoints/
```

```bash
aws s3 sync \
  /workspace/outputs/ \
  s3://<bucket-name>/outputs/
```

필요한 데이터만 선별하여 백업해도 됩니다.

---

## 16.4 Jupyter 터널 종료

로컬 PowerShell에서:

```text
Ctrl + C
```

---

## 16.5 EC2 Stop

PowerShell:

```powershell
$INSTANCE_ID = terraform -chdir=infra output -raw instance_id

aws ec2 stop-instances `
  --instance-ids $INSTANCE_ID `
  --region ap-northeast-2
```

AWS Console에서도:

```text
EC2
→ Instances
→ Instance 선택
→ Instance state
→ Stop instance
```

를 사용할 수 있습니다.

> **Terminate instance는 선택하지 않습니다.**

---

# 17. EC2를 사용하지 않을 때

GPU EC2 인스턴스는 사용하지 않을 때 **Stop** 상태로 유지하는 것을 권장합니다.

```text
학습할 때
EC2 Start
   ↓
Jupyter 접속
   ↓
GPU 학습

사용하지 않을 때
Checkpoint / 결과 저장
   ↓
S3 백업
   ↓
EC2 Stop
```

EC2 Stop 상태에서는 GPU/CPU 인스턴스 실행 비용이 중단됩니다.

하지만 다음 리소스는 계속 유지되므로 저장 비용 등이 발생할 수 있습니다.

- EBS
- S3
- Elastic IP가 별도 구성된 경우
- 기타 AWS 리소스

현재 SSM 기반 접속에서는 EC2 Stop → Start 후 Public IP가 변경되더라도 일반적으로 접속 방식에 영향이 없습니다.

---

# 18. Stop과 Terminate 차이

## Stop

```text
EC2 정지
```

다음 사용 시 다시 Start할 수 있습니다.

주요 설정 및 EBS 데이터가 유지됩니다.

권장:

```text
평소 학습환경 ON/OFF
```

---

## Terminate

```text
EC2 삭제
```

종료된 EC2 인스턴스는 다시 Start할 수 없습니다.

따라서 평소 운영에서는:

```text
Stop
```

을 사용합니다.

`Terminate`는 전체 인프라를 폐기할 때 Terraform을 통해 수행하는 것을 권장합니다.

---

# 19. Terraform은 언제 다시 사용하는가?

평소 학습환경 사용에서는 Terraform을 매번 실행하지 않습니다.

일반 운영:

```text
EC2 Start
↓
학습
↓
EC2 Stop
```

Terraform은 다음과 같은 경우 사용합니다.

- EC2 Instance Type 변경
- EBS 용량 변경
- IAM 변경
- S3 정책 변경
- 네트워크 변경
- 리소스 추가/삭제
- 전체 인프라 폐기

변경 예정 확인:

```powershell
terraform -chdir=infra plan
```

실제 반영:

```powershell
terraform -chdir=infra apply
```

---

# 20. EBS 용량 확인

EBS Volume ID:

```powershell
terraform -chdir=infra output -raw data_ebs_volume_id
```

EC2 내부:

```bash
lsblk
```

```bash
df -h /workspace
```

```bash
findmnt /workspace
```

`/workspace`가 별도 EBS에 정상적으로 연결되어 있어야 합니다.

---

# 21. Bootstrap 상태 확인

Bootstrap 문제가 의심되는 경우 SSM 접속 후:

```bash
sudo tail -n 400 /var/log/cal-bootstrap.log
```

최종 상태:

```bash
cat /workspace/bootstrap-status.txt
```

```bash
cat /workspace/bootstrap-success
```

---

# 22. Jupyter 상태 확인

```bash
sudo systemctl status cal-jupyter --no-pager
```

로그:

```bash
sudo journalctl -u cal-jupyter -n 300 --no-pager
```

Port 확인:

```bash
ss -lntp | grep 8888
```

정상:

```text
127.0.0.1:8888
```

---

# 23. SSM 상태 확인

```powershell
aws ssm describe-instance-information `
  --region ap-northeast-2 `
  --query "InstanceInformationList[?InstanceId=='$(terraform -chdir=infra output -raw instance_id)'].[InstanceId,PingStatus,AgentVersion]" `
  --output table
```

정상:

```text
Online
```

---

# 24. 인프라를 최종적으로 삭제하기 전에

프로젝트가 완전히 종료된 경우에만 Terraform으로 전체 AWS 리소스를 삭제합니다.

삭제 전 반드시 확인합니다.

- S3 원본 데이터 백업
- 학습 Dataset 백업
- 모델 checkpoint 백업
- 최종 학습 결과 백업
- Notebook / 코드 백업
- 필요한 로그 백업

특히 다음 경로를 확인합니다.

```text
/workspace/checkpoints/
/workspace/outputs/
```

S3에도 필요한 데이터가 남아 있는지 확인합니다.

```powershell
aws s3 ls "s3://$(terraform -chdir=infra output -raw s3_bucket)/" --recursive
```

---

# 25. S3 삭제 보호

현재 S3는 학습 데이터를 보호하기 위해 기본적으로 다음과 같은 설정을 사용할 수 있습니다.

```hcl
force_destroy = false
```

이 경우 S3 안에 객체가 남아 있으면 Terraform Destroy 과정에서 Bucket 삭제가 실패할 수 있습니다.

이는 실수로 학습 데이터를 모두 삭제하는 것을 방지하기 위한 설정입니다.

---

# 26. 전체 인프라 최종 삭제

## 방법 1. 데이터 보호 상태에서 삭제

먼저:

```powershell
terraform -chdir=infra plan -destroy
```

삭제 대상을 확인합니다.

문제가 없다면:

```powershell
terraform -chdir=infra destroy
```

---

## 방법 2. S3 데이터까지 완전히 삭제

**프로젝트의 모든 데이터를 정말 삭제해도 되는 경우에만** 사용합니다.

`infra/terraform.tfvars`에서:

```hcl
s3_force_destroy = true
```

로 변경합니다.

먼저 설정 반영:

```powershell
terraform -chdir=infra apply
```

그다음:

```powershell
terraform -chdir=infra destroy
```

Terraform이 질문하면:

```text
Enter a value: yes
```

입력합니다.

> `s3_force_destroy = true` 상태에서 destroy하면 S3 내부 데이터도 삭제될 수 있으므로 반드시 사전에 백업 여부를 확인합니다.

---

# 27. 전체 삭제 후 확인

Terraform:

```powershell
terraform -chdir=infra state list
```

모든 리소스가 정상 삭제되었다면 관리 대상 리소스가 남지 않아야 합니다.

EC2 확인:

```powershell
aws ec2 describe-instances `
  --region ap-northeast-2 `
  --filters "Name=tag:Project,Values=cal-ml"
```

S3 확인:

```powershell
aws s3 ls
```

EBS 확인:

```powershell
aws ec2 describe-volumes `
  --region ap-northeast-2
```

필요한 경우 AWS Console에서도 다음을 최종 확인합니다.

```text
EC2
EBS
S3
IAM
SSM
VPC
```

---

# 28. 일상적인 사용 순서 요약

## 학습을 시작할 때

```text
1. EC2 Start
2. verify-environment.ps1
3. start-jupyter-tunnel.ps1
4. JupyterLab 접속
5. nvidia-smi
6. Python venv 활성화
7. GPU 확인
8. 학습 시작
```

---

## 학습을 끝낼 때

```text
1. 학습 프로세스 종료 확인
2. Checkpoint 저장
3. 중요한 결과 S3 백업
4. Jupyter 터널 Ctrl+C 종료
5. EC2 Stop
```

---

## 프로젝트를 완전히 종료할 때

```text
1. S3 / EBS 데이터 최종 백업
2. terraform plan -destroy
3. 필요한 경우 s3_force_destroy = true
4. terraform apply
5. terraform destroy
6. AWS 리소스 잔존 여부 확인
```

---

# 29. 핵심 운영 원칙

```text
인프라 최초 생성     → Terraform
평소 학습 시작       → EC2 Start
Jupyter 접속         → SSM Port Forwarding
학습 데이터          → EBS /workspace
장기 보관            → S3
임시 고속 Cache      → NVMe
학습 종료            → EC2 Stop
인프라 변경          → Terraform plan/apply
프로젝트 최종 종료   → Terraform destroy
```

가장 중요한 원칙은 다음 세 가지입니다.

1. **평소에는 EC2를 Stop/Start 하면서 사용한다.**
2. **중요 데이터와 checkpoint는 EBS 및 S3에 저장한다.**
3. **Terminate가 아니라 최종 폐기 시 Terraform Destroy를 사용한다.**
