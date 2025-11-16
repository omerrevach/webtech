data "aws_region" "current" {}

# Security group for Interface VPC Endpoints (ECR API + ECR DKR)
resource "aws_security_group" "ecr_vpce_sg" {
  name        = "${var.name}-ecr-vpce-sg"
  description = "Security group for ECR interface endpoints"
  vpc_id      = var.vpc_id

  # Allow HTTPS from app SG only
  ingress {
    description     = "HTTPS from app EC2 only"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.app_sg_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ecr-vpce-sg"
  }
}

# ECR API endpoint (for ECR API calls)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.ecr_vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-ecr-api-vpce"
  }
}

# ECR DKR endpoint (for Docker image layer transfers)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.ecr_vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-ecr-dkr-vpce"
  }
}

# S3 Gateway endpoint (required because ECR stores layers in S3)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [var.private_route_table_id]

  tags = {
    Name = "${var.name}-s3-vpce"
  }
}
