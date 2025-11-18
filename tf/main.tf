module "vpc" {
  source = "./modules/vpc"

  name          = var.name
  cidr_block    = "10.0.0.0/16"
  public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
}

module "app" {
  source = "./modules/app"

  name              = var.name
  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnet_ids[0]
  ecr_repo_name     = "nginx"
}

module "vpc_endpoints" {
  source = "./modules/vpc_endpoints"

  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  private_route_table_id = module.vpc.private_route_table_id
  app_sg_id            = module.app.app_security_group_id
}

module "alb" {
  source = "./modules/alb"

  name             = var.name
  vpc_id           = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_sg_id        = module.app.app_security_group_id
  app_instance_id  = module.app.app_instance_id
}
