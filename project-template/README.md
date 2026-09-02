# CAL ML Project Workspace

이 디렉터리는 Terraform의 EC2 bootstrap 과정에서 `/workspace/cal-project`로 자동 배치됩니다.

## 저장 위치 원칙

- `/workspace/cal-project`: 별도 Data EBS. 코드, Notebook, 설정, checkpoint 등 **보존해야 할 파일**
- `/workspace/cache`: 가능하면 G6 Local NVMe Instance Store. 학습 데이터 cache/temp 등 **다시 생성 가능한 파일**
- `s3://$CAL_S3_BUCKET`: 원본 데이터, 전처리 완료 데이터, checkpoint, 결과의 **장기 보관 위치**

## 첫 확인

```bash
cd /workspace/cal-project
source /workspace/venv/bin/activate
./scripts/system_check.sh
python scripts/smoke_train.py
```

## 데이터 내려받기

```bash
./scripts/s3_sync_down.sh datasets/train /workspace/cache/train
```

## Checkpoint 업로드

```bash
./scripts/s3_sync_up.sh checkpoints checkpoints
```

## 권장 폴더

```text
cal-project/
├── notebooks/       # 실험/EDA Notebook
├── src/             # 재사용 가능한 Python 코드
├── configs/         # 학습 설정
├── scripts/         # 운영/점검 스크립트
├── checkpoints/     # EBS에 저장 후 S3 sync
├── outputs/         # 예측/평가 결과
├── logs/            # 로그
└── data/cache -> /workspace/cache
```

실제 모델 구조가 확정되면 `requirements.txt`의 패키지 버전을 고정하고, Notebook 안에 모든 코드를 넣기보다 `src/` 모듈로 옮기는 것을 권장합니다.
