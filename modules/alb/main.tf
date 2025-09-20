# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group for nginx-a
resource "aws_lb_target_group" "nginx_a" {
  name     = "${var.project_name}-${var.environment}-nginx-a-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-a-tg"
  }
}

# Target Group for nginx-b
resource "aws_lb_target_group" "nginx_b" {
  name     = "${var.project_name}-${var.environment}-nginx-b-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-b-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    
    forward {
      target_group {
        arn    = aws_lb_target_group.nginx_a.arn
        weight = 50
      }
      
      target_group {
        arn    = aws_lb_target_group.nginx_b.arn
        weight = 50
      }
    }
  }
}