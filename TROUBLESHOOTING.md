# Troubleshooting

최종본은 `terraform apply`가 SSM bootstrap 성공까지 확인하도록 구성되어 있습니다. 따라서 apply가 실패하면 **마지막 실패 리소스가 무엇인지** 먼저 봅니다.

---

## 1. `VcpuLimitExceeded` / GPU quota

`g6.2xlarge`는 GPU 계열 On-Demand quota가 필요합니다.
AWS Service Quotas에서 G 계열 vCPU quota를 확인합니다.

---

## 2. `TargetNotConnected` / SSM Online 실패

먼저 실제 EC2 상태:

```powershell
terraform -chdir=infra output -raw instance_id
```

```powershell
aws ec2 describe-instances `
  --instance-ids <INSTANCE_ID> `
  --region ap-northeast-3 `
  --query "Reservations[0].Instances[0].[State.Name,IamInstanceProfile.Arn]" `
  --output table
```

Instance Profile이 실제로 연결되어 있어야 합니다.

```text
arn:aws:iam::<account>:instance-profile/cal-ml-dev-instance-profile
```

SSM:

```powershell
aws ssm describe-instance-information `
  --region ap-northeast-3 `
  --query "InstanceInformationList[?InstanceId=='<INSTANCE_ID>'].[InstanceId,PingStatus,AgentVersion]" `
  --output table
```

정상:

```text
Online
```

EC2 Console의 System Log/Serial Console 접근 권한이 있다면 early user_data 로그 위치는:

```text
/var/log/cal-user-data.log
```

최신 Ubuntu DLAMI에는 SSM Agent가 기본 포함되지만 final user_data에서도 서비스 시작을 다시 보장합니다.

---

## 3. Instance Profile이 Terraform state에는 있는데 실제 EC2에 없음

검증 script:

```powershell
.\local-tools\verify-environment.ps1
```

Terraform state:

```powershell
terraform -chdir=infra state show aws_instance.ml | Select-String iam_instance_profile
```

AWS 실제:

```powershell
aws ec2 describe-iam-instance-profile-associations `
  --filters "Name=instance-id,Values=<INSTANCE_ID>" `
  --region ap-northeast-3
```

**terminated 인스턴스에는 Instance Profile을 다시 연결할 수 없습니다.**
새 final 구성을 깨끗하게 검증하려면 기존 `dev`와 충돌하지 않게 `environment = "dev2"`로 새 stack을 만드는 것이 가장 단순합니다.

---

## 4. `aws_ssm_association.bootstrap` 실패

Association ID:

```powershell
terraform -chdir=infra output -raw bootstrap_association_id
```

상태:

```powershell
aws ssm describe-association `
  --association-id <ASSOCIATION_ID> `
  --region ap-northeast-3
```

EC2에 SSM 접속이 된다면 전체 bootstrap 로그:

```bash
sudo tail -n 400 /var/log/cal-bootstrap.log
```

최종 상태:

```bash
cat /workspace/bootstrap-status.txt
cat /workspace/bootstrap-success
```

---

## 5. `/workspace` Data EBS mount 실패

AWS attachment 확인:

```powershell
aws ec2 describe-volumes `
  --volume-ids $(terraform -chdir=infra output -raw data_ebs_volume_id) `
  --region ap-northeast-3
```

EC2 내부:

```bash
lsblk -o NAME,SIZE,FSTYPE,MODEL,SERIAL,MOUNTPOINTS
cat /etc/fstab
findmnt /workspace
```

Nitro 인스턴스에서는 Terraform `/dev/sdf`가 실제 Linux에서 `/dev/nvme...`로 보이는 것이 정상입니다. Bootstrap은 Volume ID serial을 이용해 찾습니다.

---

## 6. S3 project-template이 비어 있음

이 최종본에서 가장 중요한 경로는:

```text
project root/project-template
```

Terraform은 `infra/locals.tf`에서:

```hcl
project_root = abspath("${path.module}/..")
```

기준으로 파일을 찾습니다.

Terraform plan에서 다음 리소스들이 보여야 합니다.

```text
aws_s3_object.project_template["requirements.txt"]
aws_s3_object.project_template["scripts/gpu_check.py"]
...
```

S3 확인:

```powershell
aws s3 ls "s3://$(terraform -chdir=infra output -raw s3_bucket)/bootstrap/project-template/" --recursive
```

Bootstrap도 `requirements.txt`, `scripts/gpu_check.py`가 없으면 강제로 실패하도록 되어 있습니다.

---

## 7. Jupyter 실패

EC2 내부:

```bash
sudo systemctl status cal-jupyter --no-pager
sudo journalctl -u cal-jupyter -n 300 --no-pager
ss -lntp | grep 8888
```

정상:

```text
127.0.0.1:8888
```

**Security Group에 8888 inbound를 추가하지 마세요.**
로컬에서는 SSM Port Forwarding script를 사용합니다.

---

## 8. `torch.cuda.is_available()`가 False

```bash
nvidia-smi
cd /workspace/cal-project
source /workspace/venv/bin/activate
python scripts/gpu_check.py
python scripts/smoke_train.py
```

최종 bootstrap은 `install_ml_packages=true`일 때 `smoke_train.py`까지 성공해야 Association Success가 됩니다.

---

## 9. `terraform state`가 없다고 나옴

잘못된 예:

```powershell
terraform state show aws_instance.ml
```

프로젝트 루트에서는 Terraform 파일/state가 `infra/`에 있으므로:

```powershell
terraform -chdir=infra state show aws_instance.ml
```

를 사용합니다.

모든 `local-tools`도 이 규칙으로 수정되어 있습니다.

---

## 10. EC2가 `terminated`

Terminated EC2는 다시 Start할 수 없습니다.
Terraform이 관리하는 정상 stack이라면 다음 `plan/apply`에서 새 EC2가 필요하다고 판단해야 합니다.

현재 환경 자체가 이미 여러 번 수동 변경되어 state와 실제 AWS가 불확실하다면 **새 환경 이름으로 final stack을 검증**하는 것을 권장합니다.

예:

```hcl
environment = "dev2"
```

이렇게 하면 기존 `cal-ml-dev-*` 리소스를 덧대지 않고 `cal-ml-dev2-*`로 새 환경을 한 번에 검증할 수 있습니다.

---

## 11. AMI latest가 바뀜

최종본은 최초 생성 시 최신 DLAMI를 쓰지만 기존 EC2에 대해서는:

```hcl
ignore_changes = [ami]
```

를 사용합니다.

따라서 단순한 AWS DLAMI 업데이트 때문에 학습 서버가 자동 terminate/recreate되지 않습니다.

---

## 12. `terraform destroy`에서 S3 Bucket 삭제 실패

Versioning된 데이터 보호가 기본 목적입니다.

필요한 데이터가 없다면 `infra/terraform.tfvars`에서:

```hcl
s3_force_destroy = true
```

로 바꿔 먼저 apply한 뒤 destroy합니다.

```powershell
terraform -chdir=infra apply
terraform -chdir=infra destroy
```
