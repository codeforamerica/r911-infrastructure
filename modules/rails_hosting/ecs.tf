resource "aws_ecr_repository" "containers" {
  name         = "${local.prefix}-web"
  force_delete = var.force_delete

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.hosting.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "containers" {
  repository = aws_ecr_repository.containers.name
  policy = templatefile(
    "${path.module}/templates/image-lifecycle-policy.json.tftpl",
    { untagged_image_retention : var.untagged_image_retention }
  )
}

resource "aws_ecs_cluster" "web" {
  name = "${local.prefix}-web"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${local.prefix}-web"
  execution_role_arn       = aws_iam_role.web_execution.arn
  task_role_arn            = aws_iam_role.web_task.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  container_definitions = templatefile(
    "${path.module}/templates/containers.json.tftpl",
    local.container_template_vars
  )

  cpu    = 1024
  memory = 2048

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # Maintain version history.
  skip_destroy = true

  depends_on = [aws_cloudwatch_log_group.logs]
}

resource "aws_ecs_service" "web" {
  name                              = "${local.prefix}-web"
  cluster                           = aws_ecs_cluster.web.id
  task_definition                   = local.web_task_arn
  enable_ecs_managed_tags           = true
  propagate_tags                    = "SERVICE"
  health_check_grace_period_seconds = 500
  desired_count                     = var.containers_min_capacity
  launch_type                       = "FARGATE"
  enable_execute_command            = var.enable_execute_command

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = 80
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = var.deployment_rollback
  }

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.web_private.id]
    subnets          = data.aws_subnets.private.ids
  }

  # We need to wait for the target group to be attached to the load balancer.
  depends_on = [aws_lb_listener.web_https]
}

resource "aws_appautoscaling_target" "web" {
  max_capacity       = var.containers_max_capacity
  min_capacity       = var.containers_min_capacity
  resource_id        = "service/${aws_ecs_cluster.web.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_ecs_task_definition" "db_migrate" {
  family                   = "${local.prefix}-task"
  execution_role_arn       = aws_iam_role.web_execution.arn
  task_role_arn            = aws_iam_role.web_task.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  container_definitions = templatefile(
    "${path.module}/templates/containers.json.tftpl",
    merge(
      local.container_template_vars,
      { command : "[\"bin/rails\", \"db:prepare\"]" }
    )
  )

  cpu    = 1024
  memory = 2048

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # Maintain version history.
  skip_destroy = true

  depends_on = [aws_cloudwatch_log_group.logs]
}
