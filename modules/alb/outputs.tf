output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_nginx_a_arn" {
  description = "ARN of the nginx-a target group"
  value       = aws_lb_target_group.nginx_a.arn
}

output "target_group_nginx_b_arn" {
  description = "ARN of the nginx-b target group"
  value       = aws_lb_target_group.nginx_b.arn
}