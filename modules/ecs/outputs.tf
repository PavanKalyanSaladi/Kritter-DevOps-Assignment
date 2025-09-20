output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_nginx_a_name" {
  description = "Name of the nginx-a service"
  value       = aws_ecs_service.nginx_a.name
}

output "service_nginx_b_name" {
  description = "Name of the nginx-b service"
  value       = aws_ecs_service.nginx_b.name
}