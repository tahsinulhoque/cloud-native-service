
# Find the latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Application Instance
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  # Bootstrap application during instance launch
  user_data = templatefile("${path.module}/bootstrap.sh", {
    ENVIRONMENT = var.environment
    IMAGE       = var.docker_image
  })

  user_data_replace_on_change = true

  # Encrypted root storage
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  # Enforce IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2"
  }

  # Ensure IAM permissions and CloudWatch log group exist first
  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.cloudwatch_logs,
    aws_cloudwatch_log_group.app
  ]
}
