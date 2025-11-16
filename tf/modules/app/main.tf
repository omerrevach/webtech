data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for app – ALB will be allowed to this later
resource "aws_security_group" "app_sg" {
  name        = "${var.name}-app-sg"
  description = "App EC2 security group"
  vpc_id      = var.vpc_id

  # Ingress is added from ALB module using a security_group_rule,
  # so we keep this SG tight and don't open it to the world directly.

  egress {
    description = "Allow all outbound (to VPC endpoints, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-app-sg"
  }
}

# IAM role for EC2 to read from ECR
resource "aws_iam_role" "app_role" {
  name = "${var.name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_ecr_readonly" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "${var.name}-app-instance-profile"
  role = aws_iam_role.app_role.name
}

resource "aws_instance" "nginx_app" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.app_instance_profile.name

  root_block_device {
    encrypted = true
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Basic updates
              yum update -y

              # Install Docker + AWS CLI v1
              amazon-linux-extras install docker -y
              yum install -y awscli

              systemctl enable docker
              systemctl start docker

              REGION="${data.aws_region.current.id}"
              ACCOUNT_ID="${data.aws_caller_identity.current.account_id}"
              REPO_NAME="${var.ecr_repo_name}"

              # Login to ECR using AWS CLI v1
              eval $(aws ecr get-login --no-include-email --region $REGION)

              # Run Nginx container from ECR
              docker run -d -p 80:80 --name nginx-app \
                $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest
              EOF

  tags = {
    Name = "${var.name}-nginx-app"
  }
}

