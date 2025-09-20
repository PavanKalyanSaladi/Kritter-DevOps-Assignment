provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "DevOps-IaC-Demo"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = local.azs
  
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
}

# ALB Module
module "alb" {
  source = "./modules/alb"
  
  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  alb_security_group_id   = module.networking.alb_security_group_id
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.networking.vpc_id
  private_app_subnet_ids    = module.networking.private_app_subnet_ids
  ecs_security_group_id     = module.networking.ecs_security_group_id
  target_group_nginx_a_arn  = module.alb.target_group_nginx_a_arn
  target_group_nginx_b_arn  = module.alb.target_group_nginx_b_arn
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_instance_role_name    = module.iam.ecs_instance_role_name
  ecs_instance_profile_name = module.iam.ecs_instance_profile_name
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"
  
  project_name               = var.project_name
  environment                = var.environment
  lambda_execution_role_arn  = module.iam.lambda_execution_role_arn
  s3_bucket_name             = "${var.project_name}-${var.environment}-uploads-${random_id.bucket_suffix.hex}"
}

# Random ID for S3 bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}