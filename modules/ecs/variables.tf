variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID of the ECS security group"
  type        = string
}

variable "target_group_nginx_a_arn" {
  description = "ARN of the nginx-a target group"
  type        = string
}

variable "target_group_nginx_b_arn" {
  description = "ARN of the nginx-b target group"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_instance_role_name" {
  description = "Name of the ECS instance role"
  type        = string
}

variable "ecs_instance_profile_name" {
  description = "Name of the ECS instance profile"
  type        = string
}