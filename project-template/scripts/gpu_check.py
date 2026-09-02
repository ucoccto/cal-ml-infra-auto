"""EC2 GPU 및 PyTorch CUDA 인식 여부를 빠르게 확인한다."""

from __future__ import annotations

import platform


def main() -> None:
    print(f"Python platform: {platform.platform()}")

    try:
        import torch
    except ImportError:
        print("PyTorch가 아직 설치되지 않았습니다.")
        return

    print(f"PyTorch: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    print(f"PyTorch CUDA runtime: {torch.version.cuda}")

    if torch.cuda.is_available():
        print(f"GPU count: {torch.cuda.device_count()}")
        for index in range(torch.cuda.device_count()):
            props = torch.cuda.get_device_properties(index)
            memory_gib = props.total_memory / 1024**3
            print(f"GPU[{index}]: {props.name}, VRAM={memory_gib:.1f} GiB")


if __name__ == "__main__":
    main()
