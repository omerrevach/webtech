resource "aws_s3_bucket" "tf_state" {
  bucket = "nginx-test-env-tf-state-omer-1234"

  tags = {
    Name = "nginx-test-env-tf-state"
  }
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_encryption" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state_public_block" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}


module "vpc" {
  source = "./modules/vpc"

  name          = var.name
  cidr_block    = "10.0.0.0/16"
  public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  depends_on = [aws_s3_bucket.tf_state]
}

module "app" {
  source = "./modules/app"

  name              = var.name
  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnet_ids[0]
  ecr_repo_name     = "nginx"

  depends_on = [aws_s3_bucket.tf_state]
}

module "vpc_endpoints" {
  source = "./modules/vpc_endpoints"

  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  private_route_table_id = module.vpc.private_route_table_id
  app_sg_id            = module.app.app_security_group_id

  depends_on = [aws_s3_bucket.tf_state]
}

module "alb" {
  source = "./modules/alb"

  name             = var.name
  vpc_id           = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_sg_id        = module.app.app_security_group_id
  app_instance_id  = module.app.app_instance_id

  depends_on = [aws_s3_bucket.tf_state]
}
