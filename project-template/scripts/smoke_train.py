"""실제 모델 학습 전에 GPU 연산이 정상인지 확인하는 매우 작은 smoke test."""

from __future__ import annotations

import time

import torch


def main() -> None:
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA GPU를 사용할 수 없습니다. gpu_check.py 결과를 먼저 확인하세요.")

    device = torch.device("cuda")
    print(f"Device: {torch.cuda.get_device_name(0)}")

    # 지나치게 큰 메모리를 사용하지 않는 행렬 곱으로 CUDA 연산을 확인한다.
    x = torch.randn((4096, 4096), device=device)
    y = torch.randn((4096, 4096), device=device)

    torch.cuda.synchronize()
    start = time.perf_counter()
    _ = x @ y
    torch.cuda.synchronize()
    elapsed = time.perf_counter() - start

    allocated = torch.cuda.memory_allocated() / 1024**3
    print(f"GPU matrix multiply: {elapsed:.3f}s")
    print(f"Allocated VRAM: {allocated:.2f} GiB")
    print("Smoke test OK")


if __name__ == "__main__":
    main()
