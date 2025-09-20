# Get latest ECS optimized AMI
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

# Parse AMI ID from SSM parameter
locals {
  ecs_ami = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# Launch Template
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-${var.environment}-ecs-"
  image_id      = local.ecs_ami
  instance_type = "t3.micro"

  vpc_security_group_ids = [var.ecs_security_group_id]

  iam_instance_profile {
    name = var.ecs_instance_profile_name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-ecs-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-${var.environment}-ecs-asg"
  vpc_zone_identifier = var.private_app_subnet_ids
  target_group_arns   = [var.target_group_nginx_a_arn, var.target_group_nginx_b_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 3
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = false
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ecs-asg"
    propagate_at_launch = false
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-logs"
  }
}

# ECS Task Definition for nginx-a
resource "aws_ecs_task_definition" "nginx_a" {
  family                   = "${var.project_name}-${var.environment}-nginx-a"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "nginx-a"
      image = "nginx:latest"
      
      memory = 256
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      command = [
        "/bin/sh",
        "-c",
        "echo '<h1>Hello from nginx-a service!</h1><p>This is service A</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "nginx-a"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-a-task"
  }
}

# ECS Task Definition for nginx-b
resource "aws_ecs_task_definition" "nginx_b" {
  family                   = "${var.project_name}-${var.environment}-nginx-b"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "nginx-b"
      image = "nginx:latest"
      
      memory = 256
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      command = [
        "/bin/sh",
        "-c",
        "echo '<h1>Hello from nginx-b service!</h1><p>This is service B</p>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "nginx-b"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-b-task"
  }
}

# ECS Service for nginx-a
resource "aws_ecs_service" "nginx_a" {
  name            = "nginx-a"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx_a.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = var.target_group_nginx_a_arn
    container_name   = "nginx-a"
    container_port   = 80
  }

  depends_on = [aws_autoscaling_group.ecs]

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-a-service"
  }
}

# ECS Service for nginx-b
resource "aws_ecs_service" "nginx_b" {
  name            = "nginx-b"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx_b.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = var.target_group_nginx_b_arn
    container_name   = "nginx-b"
    container_port   = 80
  }

  depends_on = [aws_autoscaling_group.ecs]

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-b-service"
  }
}

# Data source for current region
data "aws_region" "current" {}