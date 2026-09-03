# CAL 3D Printing Deep Learning - AWS Terraform 환경

CAL(Computed Axial Lithography) projection enhancement 프로젝트용 **GPU EC2 + S3 + EBS + SSM + JupyterLab** 자동 구축 프로젝트입니다.

이 최종본은 프로젝트 구조를 다음 한 가지 기준으로 통일했습니다.

```text
cal-ml-aws/
├── infra/                    # Terraform은 항상 여기
├── templates/                # EC2 early user_data + 전체 bootstrap
├── project-template/         # Jupyter 프로젝트 초기 파일
├── local-tools/              # 접속/Start/Stop/검증 스크립트
├── deploy.ps1                # Windows 원클릭 배포
├── deploy.sh                 # Linux/macOS 원클릭 배포
├── Makefile
├── REVIEW_NOTES.md
└── TROUBLESHOOTING.md
```

## 최종 아키텍처

```text
Local PC
  │
  │ Terraform
  ▼
AWS
├── VPC / Public Subnet / Internet Gateway
│
├── IAM Role + Instance Profile
│   ├── AmazonSSMManagedInstanceCore
│   └── Project S3 Read/Write
│
├── S3
│   ├── raw/
│   ├── processed/
│   ├── augmented/
│   ├── datasets/
│   ├── checkpoints/
│   ├── outputs/
│   └── bootstrap/project-template/
│
├── Data EBS gp3 300 GiB
│         │
│         ▼
│   /workspace
│
└── EC2 g6.2xlarge
    ├── Ubuntu 24.04 GPU DLAMI
    ├── NVIDIA L4 GPU
    ├── SSM Agent
    ├── Local NVMe -> /workspace/cache
    └── JupyterLab -> 127.0.0.1:8888
```

## 왜 bootstrap을 SSM Association으로 변경했나

기존 방식은 EC2 `user_data`가 Data EBS attach와 동시에 실행되었습니다. Terraform 입장에서는 EC2 생성과 EBS attachment가 별도 리소스이므로, OS 내부 설치 시점과 EBS attach 시점 사이에 race가 생길 수 있습니다. 또한 Terraform `apply`가 끝나도 pip/Jupyter 설치가 계속 진행 중이거나 실패했는지 알 수 없었습니다.

최종본은 다음 순서입니다.

```text
1. VPC / IAM / S3 / EBS 생성
2. EC2 생성 + Instance Profile 연결
3. user_data가 SSM Agent를 즉시 시작
4. Data EBS attach
5. SSM State Manager Association 실행
6. /workspace mount
7. S3 project-template download
8. Python venv / PyTorch / Jupyter 설치
9. NVIDIA / CUDA / S3 / Jupyter smoke test
10. Association Success
11. terraform apply 완료
```

즉 **`terraform apply` 성공 = bootstrap Association도 성공**을 목표로 구성했습니다.

---

# 1. 로컬 PC 사전 준비

필요 도구:

- Terraform >= 1.7
- AWS CLI v2
- AWS Session Manager Plugin
- AWS Credentials

먼저 AWS 인증을 확인합니다.

```powershell
aws sts get-caller-identity
```

---

# 2. 변수 파일 준비

Windows PowerShell:

```powershell
Copy-Item .\infra\terraform.tfvars.example .\infra\terraform.tfvars
```

Linux/macOS:

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
```

기본 구성은 다음과 같습니다.

```hcl
instance_type    = "g6.2xlarge"
root_volume_size = 100
data_volume_size = 300
enable_ssh        = false
```

현재 사용 중인 `dev` 환경과 충돌 없이 새 구성으로 테스트하려면 임시로:

```hcl
environment = "dev2"
```

처럼 별도 환경 이름을 쓰는 것이 가장 안전합니다.

---

# 3. 가장 간단한 전체 배포

## Windows

프로젝트 루트에서:

```powershell
.\deploy.ps1
```

## Linux/macOS

```bash
./deploy.sh
```

스크립트가 다음을 순서대로 수행합니다.

```text
AWS 인증 확인
→ terraform init
→ terraform fmt
→ terraform validate
→ terraform plan
→ 사용자 yes 확인
→ terraform apply
→ SSM bootstrap 성공까지 대기
```

---

# 4. Terraform을 직접 실행하고 싶다면

Terraform 파일은 모두 `infra/`에 있습니다.

```powershell
terraform -chdir=infra init
terraform -chdir=infra fmt -recursive
terraform -chdir=infra validate
terraform -chdir=infra plan
terraform -chdir=infra apply
```

**프로젝트 루트에서 `terraform state ...`를 직접 실행하지 않습니다.** 항상 `-chdir=infra`를 사용하거나 `infra` 디렉터리로 이동합니다.

---

# 5. 배포 완료 후 자동 검증

Windows:

```powershell
.\local-tools\verify-environment.ps1
```

Linux/macOS:

```bash
./local-tools/verify-environment.sh
```

다음을 한 번에 확인합니다.

```text
EC2 = running
IAM Instance Profile = 실제 EC2에 연결
SSM = Online
Data EBS = attached
Bootstrap Association = Success
```

---

# 6. JupyterLab 접속

Jupyter 8888은 Security Group에 공개하지 않습니다.
EC2 내부 `127.0.0.1:8888`에만 listen하고 SSM Port Forwarding으로 접근합니다.

Windows:

```powershell
.\local-tools\start-jupyter-tunnel.ps1
```

Linux/macOS:

```bash
./local-tools/start-jupyter-tunnel.sh
```

브라우저:

```text
http://127.0.0.1:8888/lab
```

---

# 7. EC2 Terminal 접속

Windows:

```powershell
.\local-tools\start-ssm.ps1
```

Linux/macOS:

```bash
./local-tools/start-ssm.sh
```

접속 후 Ubuntu 개발 사용자로 전환합니다.

```bash
sudo -iu ubuntu
```

환경 확인:

```bash
cd /workspace/cal-project
source /workspace/venv/bin/activate
./scripts/system_check.sh
python scripts/smoke_train.py
```

Bootstrap 결과:

```bash
cat /workspace/bootstrap-status.txt
cat /workspace/bootstrap-success
```

로그:

```bash
sudo tail -n 300 /var/log/cal-bootstrap.log
```

---

# 8. 데이터 저장 원칙

| 데이터 | 권장 위치 | 설명 |
|---|---|---|
| STL 원본 | S3 `raw/stl/` | 장기 보관 |
| Voxel/Projection/Feature | S3 `processed/` | 재사용 가능한 가공 데이터 |
| 학습 Dataset | S3 + `/workspace/cache` | S3 원본, NVMe 학습 cache |
| Notebook/Source | `/workspace/cal-project` | Data EBS에 보존 |
| 임시 augmentation | `/workspace/cache` | Local NVMe 사용 |
| Checkpoint | EBS + S3 `checkpoints/` | 중단 복구 |
| 최종 모델/평가 결과 | S3 `outputs/` | 장기 보관 |

`g6.2xlarge`의 Local NVMe는 빠르지만 Stop/Terminate 시 보존 대상으로 보면 안 됩니다.

---

# 9. S3 사용

Train dataset 내려받기:

```bash
cd /workspace/cal-project
./scripts/s3_sync_down.sh datasets/train /workspace/cache/train
```

Checkpoint 업로드:

```bash
./scripts/s3_sync_up.sh checkpoints checkpoints
```

S3의 `raw/`, `datasets/` 같은 항목은 실제 디렉터리가 아니라 Object Key prefix입니다. 빈 folder marker 객체를 Terraform으로 만들지 않습니다.

---

# 10. 비용 절감: EC2 Stop / Start

작업 종료:

```powershell
.\local-tools\stop-ec2.ps1
```

다음 작업 시작:

```powershell
.\local-tools\start-ec2.ps1
```

Start script는 EC2 `running`뿐 아니라 **SSM Online까지 기다립니다.**

Stop 상태에서는 GPU compute 비용은 중단되지만 EBS/S3 저장 비용은 계속 발생합니다.

---

# 11. AMI 업데이트 정책

최초 EC2 생성 시 AWS Public SSM Parameter의 최신 Ubuntu 24.04 GPU DLAMI를 사용합니다.

다만 AWS가 `latest` 값을 갱신할 때마다 기존 GPU 서버가 자동 교체되는 것은 학습 환경에서 위험하므로:

```hcl
lifecycle {
  ignore_changes = [ami]
}
```

를 적용했습니다.

즉:

- 최초 생성: 그 시점의 최신 DLAMI
- 일반 `terraform apply`: 최신 AMI가 바뀌어도 기존 EC2 유지
- EC2가 실제로 재생성돼야 할 때: 당시 최신 DLAMI 사용

---

# 12. 전체 삭제

기본값:

```hcl
s3_force_destroy = false
```

이므로 S3에 학습 데이터/Version이 남으면 안전을 위해 Bucket 삭제가 막힐 수 있습니다.

교육용 완전 삭제가 목적이라면 데이터가 필요 없는지 확인한 뒤:

```hcl
s3_force_destroy = true
```

로 변경해 `apply` 후 `destroy`할 수 있습니다.

```powershell
terraform -chdir=infra apply
terraform -chdir=infra destroy
```

---

# 주요 파일

```text
infra/ec2.tf
  EC2 + Instance Profile + early SSM user_data

infra/storage.tf
  영구 Data EBS + attachment

infra/bootstrap.tf
  EBS attach 이후 전체 개발환경을 설치하는 SSM Association

infra/s3.tf
  S3 Bucket + project-template upload

templates/user_data.sh.tftpl
  SSM Agent 조기 시작만 담당

templates/bootstrap.sh.tftpl
  EBS/Python/PyTorch/Jupyter/GPU smoke test 전체 자동화

local-tools/verify-environment.*
  실제 AWS 상태 검증
```

자세한 수정 이유는 `REVIEW_NOTES.md`, 장애 진단은 `TROUBLESHOOTING.md`를 참고하세요.
