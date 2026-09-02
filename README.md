# CAL 3D Printing Deep Learning - AWS Terraform 환경

CAL(Computed Axial Lithography) projection enhancement 프로젝트를 위한 **GPU EC2 + S3 + EBS + JupyterLab 개발환경 자동 구축** 예제입니다.

## Terraform이 자동으로 만드는 것

```text
AWS
├── VPC
│   └── Public Subnet
│       └── EC2 g6.2xlarge
│           ├── AWS GPU DLAMI (Ubuntu 24.04)
│           ├── NVIDIA Driver / CUDA (DLAMI 제공)
│           ├── Root EBS 100GiB
│           ├── Data EBS 300GiB -> /workspace
│           ├── Local NVMe -> /workspace/cache (가능한 경우)
│           ├── Python venv -> /workspace/venv
│           ├── PyTorch + JupyterLab + 과학계산 패키지
│           └── Jupyter systemd service (127.0.0.1:8888)
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
├── IAM
│   ├── SSM Session Manager
│   └── 프로젝트 S3 Bucket Read/Write
│
└── AWS Budget (budget_email 설정 시 선택 생성)
```

## 중요한 설계 원칙

1. **Jupyter 8888 포트를 인터넷에 열지 않습니다.**
2. 접속은 기본적으로 **AWS Systems Manager Session Manager**를 사용합니다.
3. 코드/Notebook/checkpoint는 별도 EBS `/workspace`에 보존합니다.
4. 빠른 Local NVMe는 cache/temp에만 사용합니다.
5. 원본/가공 데이터와 최종 checkpoint는 S3를 Source of Truth로 사용합니다.
6. EC2는 학습할 때만 Start하고 사용 후 Stop하여 GPU 비용을 줄입니다.

---

# 1. 로컬 PC 사전 준비

필요 도구:

- Terraform
- AWS CLI
- AWS Session Manager Plugin
- AWS 계정 Credentials

AWS CLI 확인:

```bash
aws sts get-caller-identity
```

---

# 2. 변수 파일 생성

Linux/macOS:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Windows PowerShell:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

기본값은 `g6.2xlarge`, Root 100GiB, Data EBS 300GiB입니다.

비용 알림을 사용하려면 `terraform.tfvars`에 추가합니다.

```hcl
budget_email       = "student@example.com"
monthly_budget_usd = 250
```

---

# 3. 인프라 생성

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

적용 후:

```bash
terraform output
```

> AWS 계정의 G 계열 On-Demand vCPU quota가 부족하면 EC2 생성이 실패할 수 있습니다. 이 경우 Service Quotas에서 G 인스턴스 quota를 먼저 확인합니다.

---

# 4. Bootstrap 완료 확인

Terraform의 EC2 생성 완료와 OS 내부 패키지 설치 완료 시점은 다를 수 있습니다.
SSM으로 접속한 뒤 cloud-init 상태를 확인합니다.

```bash
cloud-init status --wait
sudo tail -n 200 /var/log/cal-bootstrap.log
cat /workspace/bootstrap-status.txt
```

정상 완료 후 주요 경로:

```text
/workspace/
├── cal-project/       # 코드 / Notebook / checkpoint
├── venv/              # Python 가상환경
└── cache -> NVMe      # 가능하면 Local NVMe 사용
```

---

# 5. EC2 Terminal 접속

Terraform output에 접속 명령이 제공됩니다.

```bash
terraform output -raw ssm_session_command
```

또는:

Linux/macOS:

```bash
./local-tools/start-ssm.sh
```

Windows:

```powershell
.\local-tools\start-ssm.ps1
```

---

# 6. JupyterLab 접속

Jupyter는 EC2의 `127.0.0.1:8888`에만 열려 있습니다.
따라서 로컬 PC와 EC2 사이에 SSM Port Forwarding Tunnel을 만듭니다.

Windows:

```powershell
.\local-tools\start-jupyter-tunnel.ps1
```

Linux/macOS:

```bash
./local-tools/start-jupyter-tunnel.sh
```

Tunnel이 열린 상태에서 브라우저로 접속합니다.

```text
http://127.0.0.1:8888/lab
```

Jupyter 자체의 token/password는 비활성화되어 있지만 **127.0.0.1에만 bind**되어 있고, 실제 사용자 인증은 AWS SSM 세션에서 수행됩니다.

---

# 7. GPU 환경 확인

SSM Session Manager의 기본 shell 사용자는 환경에 따라 `ssm-user`일 수 있습니다.
프로젝트 개발은 `ubuntu` 사용자로 전환한 뒤 진행하는 것을 권장합니다.

```bash
sudo -iu ubuntu
```

그다음:

```bash
cd /workspace/cal-project
source /workspace/venv/bin/activate

nvidia-smi
python scripts/gpu_check.py
python scripts/smoke_train.py
```

---

# 8. S3 데이터 사용

환경 변수는 bootstrap에서 자동 등록합니다.

```bash
echo $CAL_S3_BUCKET
echo $CAL_PROJECT_DIR
echo $CAL_CACHE_DIR
```

Train 데이터 내려받기:

```bash
cd /workspace/cal-project
./scripts/s3_sync_down.sh datasets/train /workspace/cache/train
```

Checkpoint 업로드:

```bash
./scripts/s3_sync_up.sh checkpoints checkpoints
```

---

# 9. 데이터 저장 위치 권장

| 데이터 | 위치 | 이유 |
|---|---|---|
| STL 원본 | S3 `raw/stl/` | 장기 보관 |
| Voxel/Projection/Feature | S3 `processed/` | 재사용 데이터 |
| 실제 학습 Dataset | S3 + `/workspace/cache` | S3 보관 + NVMe 학습 cache |
| Notebook/Source | Data EBS `/workspace/cal-project` | Stop 후에도 보존 |
| 임시 augmentation | `/workspace/cache` | 빠른 NVMe 활용 |
| Checkpoint | EBS + S3 `checkpoints/` | 중단 복구 |
| 최종 모델/평가 결과 | S3 `outputs/` | 장기 보관 |

---

# 10. EC2 Start / Stop

GPU EC2 비용이 가장 크므로 학습할 때만 Start하고 끝났으면 **Terminate가 아니라 Stop** 합니다.

Windows:

```powershell
.\local-tools\start-ec2.ps1
.\local-tools\stop-ec2.ps1
```

Linux/macOS:

```bash
./local-tools/start-ec2.sh
./local-tools/stop-ec2.sh
```

Stop 상태에서는 EC2 compute 요금은 발생하지 않지만 EBS/S3 저장비용은 계속 발생합니다.
Local NVMe 데이터는 보존 대상으로 생각하지 말고 S3/EBS에 필요한 데이터를 먼저 저장해야 합니다.

---

# 11. 전체 삭제

S3에 데이터가 남아 있으면 안전을 위해 Bucket 삭제가 막힐 수 있습니다.
프로젝트 데이터가 필요하면 먼저 백업합니다.

```bash
terraform destroy
```

교육용으로 Bucket까지 강제 삭제하고 싶다면 `s3.tf`의 `force_destroy` 정책을 신중히 변경하십시오.

---

# 파일 구조

```text
cal-ml-complete/
├── versions.tf
├── provider.tf
├── variables.tf
├── locals.tf
├── network.tf
├── s3.tf
├── iam.tf
├── storage.tf
├── ec2.tf
├── budget.tf
├── outputs.tf
├── terraform.tfvars.example
├── Makefile
├── TROUBLESHOOTING.md
├── templates/
│   └── user_data.sh.tftpl
├── project-template/
│   ├── README.md
│   ├── requirements.txt
│   ├── configs/
│   ├── notebooks/
│   ├── scripts/
│   └── src/
└── local-tools/
    ├── start-ec2.ps1
    ├── start-ec2.sh
    ├── stop-ec2.ps1
    ├── stop-ec2.sh
    ├── start-ssm.ps1
    ├── start-ssm.sh
    ├── start-jupyter-tunnel.ps1
    └── start-jupyter-tunnel.sh
```
