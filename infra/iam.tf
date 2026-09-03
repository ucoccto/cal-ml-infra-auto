# EC2가 사용할 IAM Role Trust Policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ml_ec2" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Session Manager / State Manager 통신에 필요한 AWS 관리형 정책
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ml_ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 프로젝트 전용 S3 Bucket에 대해서만 읽기/쓰기 권한을 준다.
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "ListProjectBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [aws_s3_bucket.data.arn]
  }

  statement {
    sid    = "ReadWriteProjectObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${aws_s3_bucket.data.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "${var.project_name}-${var.environment}-s3-policy"
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ml_ec2.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# EC2 시작 시 IAM Role을 전달하는 Instance Profile
resource "aws_iam_instance_profile" "ml_ec2" {
  name = "${var.project_name}-${var.environment}-instance-profile"
  role = aws_iam_role.ml_ec2.name
}
