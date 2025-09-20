output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = module.lambda.api_gateway_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for uploads"
  value       = module.lambda.s3_bucket_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}