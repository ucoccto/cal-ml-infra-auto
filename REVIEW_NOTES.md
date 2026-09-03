# 프로젝트 전체 검토 결과

## 1. 가장 큰 구조 문제: `infra/` 기준과 프로젝트 루트 기준이 혼재

제공된 전체 프로젝트에는 다음이 프로젝트 루트에 있었습니다.

```text
templates/
project-template/
local-tools/
README.md
```

반면 Terraform은 별도 `infra/` 디렉터리에 있었습니다.

기존 `locals.tf`는:

```hcl
fileset("${path.module}/project-template", "**")
```

를 사용했습니다. `path.module`이 `infra/`이므로 실제로는:

```text
infra/project-template
```

를 찾게 됩니다. 제공된 `infra.zip`에는 이 디렉터리가 없습니다.

그 결과 `aws_s3_object.project_template`이 기대대로 생성되지 않을 수 있었고, 실제 첫 apply 로그에도 `aws_s3_object.project_template[...]` 생성 로그가 나타나지 않았습니다.

최종본은 모든 경로를:

```hcl
project_root = abspath("${path.module}/..")
```

기준으로 통일했습니다.

---

## 2. 로컬 도구도 잘못된 Terraform 실행 위치를 사용

기존:

```powershell
terraform output -raw instance_id
```

는 프로젝트 루트에서 Terraform state를 찾습니다.

하지만 실제 state/config는 `infra/`입니다. 이 때문에 실제 대화에서도:

```text
No state file was found!
```

가 발생했습니다.

최종본은 모든 PowerShell/Shell/Makefile을 `infra/` 기준으로 변경했습니다.

---

## 3. EC2 `user_data`와 EBS attach 사이의 race

기존 구조:

```text
aws_instance.ml 생성
   └─ user_data 즉시 실행

aws_volume_attachment.data
   └─ EC2가 만들어진 다음 attach
```

이 둘은 OS 내부에서 완전히 동기화되지 않습니다.
기존 script가 EBS를 기다리기는 했지만 Terraform `apply`는 Jupyter/PyTorch 설치 성공까지 확인하지 못합니다.

최종본:

```text
EC2 생성
→ SSM Agent Online
→ EBS attach
→ S3 bootstrap script 업로드
→ aws_ssm_association.bootstrap (AWS-RunRemoteScript)
→ 전체 bootstrap
→ Smoke Test
→ Association Success
→ terraform apply 완료
```

으로 변경했습니다.

---

## 4. SSM Agent 시작이 너무 늦었음

기존 `user_data`는 먼저:

```text
apt-get update
apt-get install ...
```

을 수행하고 그 뒤 SSM Agent를 시작했습니다.

패키지 설치가 오래 걸리거나 실패하면 SSM에 접속해서 문제를 볼 수도 없습니다.

최종본의 EC2 `user_data`는 **SSM Agent 시작만 가장 먼저 수행**합니다.
전체 설치는 State Manager로 분리했습니다.

---

## 5. IAM Instance Profile은 HCL에 이미 존재했음

기존 `ec2.tf`에는 이미:

```hcl
iam_instance_profile = aws_iam_instance_profile.ml_ec2.name
```

가 있었습니다.

따라서 이번 `TargetNotConnected`를 단순히 "코드에 iam_instance_profile이 빠졌다"고 볼 수는 없습니다.

실제 확인 과정에서 기존 EC2는 결국:

```text
terminated
```

상태였고, 종료된 인스턴스에는 Instance Profile을 새로 연결할 수 없습니다.

최종 구조에서는 `aws_ssm_association.bootstrap`이 성공해야 전체 `apply`가 성공하므로, Instance Profile/SSM 연결이 실제로 안 된 상태가 정상 배포로 끝나는 것을 방지합니다.

---

## 6. 최신 AMI 자동 교체 위험

기존 구성은 매 plan마다 AWS의 `latest` DLAMI Parameter를 조회합니다.
AMI 값은 EC2 교체 속성이므로 AWS가 latest를 바꾸면 의도치 않은 교체가 생길 수 있습니다.

최종본은 최신 AMI를 최초 생성에 사용하되:

```hcl
ignore_changes = [ami]
```

로 기존 서버 자동 교체를 막았습니다.

---

## 7. S3 빈 폴더 객체 제거

S3는 파일시스템 디렉터리가 아니라 Object Key prefix 기반입니다.
기존 `aws_s3_object.folders`처럼 `datasets/` 등의 0-byte 객체를 관리할 필요가 없습니다.

최종본은 실제 데이터와 bootstrap 파일만 객체로 관리합니다.

---

## 8. Bootstrap 자체 검증 강화

최종 bootstrap은 다음 중 하나라도 실패하면 SSM Association이 실패합니다.

```text
Data EBS mount 실패
S3 project-template 필수 파일 없음
Python/Pip package 설치 실패
Jupyter service 실패
NVIDIA nvidia-smi 실패
S3 접근 실패
PyTorch CUDA smoke test 실패
```

성공하면:

```text
/workspace/bootstrap-success
/workspace/bootstrap-status.txt
```

를 만듭니다.

---

## 9. 실제 운영 편의성 보강

추가/수정:

- `deploy.ps1`, `deploy.sh`
- `verify-environment.ps1`, `verify-environment.sh`
- Start script에서 EC2뿐 아니라 SSM Online까지 확인
- `instance_initiated_shutdown_behavior = "stop"`
- EBS detach 시 `stop_instance_before_detaching = true`
- `terraform.tfvars.example` 실제 `infra/`에 추가
- README의 모든 Terraform 명령을 `-chdir=infra` 기준으로 수정

---

## 최종 성공 기준

`deploy`가 정상 완료된 뒤 `verify-environment`에서 다음 5개가 모두 `[OK]`여야 합니다.

```text
EC2
IAM Instance Profile
SSM
Data EBS
Bootstrap Association
```

그 후 Jupyter tunnel을 열면 됩니다.
