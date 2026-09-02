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

# Linux에서 /dev/sdf로 요청하더라도 Nitro 계열 인스턴스에서는 실제로 NVMe 장치명으로 보일 수 있다.
# bootstrap script가 EBS Volume ID를 기준으로 실제 장치를 찾아 /workspace에 마운트한다.
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.ml.id
}
