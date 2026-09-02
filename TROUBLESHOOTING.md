# Troubleshooting

## 1. `VcpuLimitExceeded` / G instance quota 오류

AWS Service Quotas에서 GPU 계열 On-Demand vCPU quota를 확인합니다. `g6.2xlarge`는 8 vCPU가 필요합니다.

## 2. SSM 접속이 안 됨

EC2가 `running`인지 확인하고 몇 분 뒤 다음을 확인합니다.

```bash
aws ssm describe-instance-information --region ap-northeast-2
```

EC2 내부에서 확인할 수 있다면:

```bash
sudo systemctl status amazon-ssm-agent || true
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent || true
```

## 3. Bootstrap 실패

```bash
cloud-init status --long
sudo tail -n 300 /var/log/cal-bootstrap.log
```

Data EBS attach, S3 bootstrap download, pip install 중 어느 단계에서 실패했는지 확인합니다.

## 4. `/workspace`가 마운트되지 않음

```bash
lsblk -o NAME,SIZE,FSTYPE,MODEL,SERIAL,MOUNTPOINTS
cat /etc/fstab
```

`data_ebs_volume_id`와 NVMe serial을 비교합니다. Nitro 인스턴스에서는 Terraform의 `/dev/sdf`가 Linux 안에서 `/dev/nvme...`로 보이는 것이 정상입니다.

## 5. Jupyter가 안 열림

EC2 내부:

```bash
sudo systemctl status cal-jupyter
sudo journalctl -u cal-jupyter -n 200 --no-pager
ss -lntp | grep 8888
```

정상이라면 Jupyter는 `127.0.0.1:8888`에만 listen합니다. Security Group에 8888 inbound를 추가하지 마십시오.

로컬 PC에서는 AWS Session Manager Plugin이 설치되어 있는지 확인합니다.

## 6. `torch.cuda.is_available()`가 False

```bash
nvidia-smi
source /workspace/venv/bin/activate
python /workspace/cal-project/scripts/gpu_check.py
```

`nvidia-smi` 자체가 실패하면 DLAMI/GPU driver 또는 인스턴스 타입을 먼저 확인합니다. `nvidia-smi`는 정상인데 PyTorch만 실패하면 설치된 PyTorch wheel을 다시 확인합니다.

## 7. 디스크 부족

```bash
df -h
du -sh /workspace/*
du -sh /opt/dlami/nvme/* 2>/dev/null || true
```

대용량 학습 데이터는 S3에 보관하고 현재 학습에 필요한 데이터만 `/workspace/cache`로 내려받는 것을 권장합니다. Data EBS는 필요 시 Terraform의 `data_volume_size`를 늘릴 수 있지만 축소는 별도 마이그레이션이 필요합니다.

## 8. 비용이 예상보다 커짐

가장 먼저 EC2가 계속 `running`인지 확인합니다. 작업이 끝난 후:

```bash
./local-tools/stop-ec2.sh
```

또한 EBS, S3 저장공간과 오래된 S3 Version을 확인합니다.
