# 코드/Notebook/checkpoint처럼 반드시 보존해야 하는 데이터를 저장할 별도 EBS다.
# EC2와 같은 AZ에 있어야 attach할 수 있다.
resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  type              = "gp3"
  size              = var.data_volume_size
  encrypted         = true
  iops              = var.data_volume_iops
  throughput        = var.data_volume_throughput

  tags = {
    Name = "${var.project_name}-${var.environment}-data"
  }
}

# Linux에서 /dev/sdf로 요청해도 Nitro 계열에서는 실제 /dev/nvme*n1로 보인다.
# bootstrap script는 EBS Volume ID의 NVMe serial을 사용해 실제 장치를 찾는다.
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.ml.id

  # 향후 EC2 교체 시 데이터 손상 위험을 낮추기 위해 정상 stop 후 detach한다.
  stop_instance_before_detaching = true
}
