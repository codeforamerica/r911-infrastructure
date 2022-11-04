locals {
  warehouse_interfaces = toset(distinct(flatten([
    for endpoint in aws_redshiftserverless_workgroup.warehouse.endpoint : [
      for vpc_endpoint in endpoint.vpc_endpoint : [
        for interface in vpc_endpoint.network_interface : interface.private_ip_address
      ]
    ]
  ])))
}

resource "aws_lb_target_group" "warehouse" {
  name            = "${local.prefix}-data-warehouse"
  port            = 5439
  protocol        = "TCP"
  vpc_id          = var.vpc_id
  target_type     = "ip"
  ip_address_type = "ipv4"

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "warehouse" {
  depends_on = [aws_redshiftserverless_workgroup.warehouse]
  for_each   = local.warehouse_interfaces

  target_group_arn = aws_lb_target_group.warehouse.arn
  target_id        = each.value
  port             = 5439
}

resource "aws_lb" "warehouse" {
  name               = "${local.prefix}-data-warehouse"
  load_balancer_type = "network"
  subnets            = data.aws_subnets.public.ids

  #tfsec:ignore:aws-elb-alb-not-public
  internal = false

  access_logs {
    enabled = true
    bucket  = var.logging_bucket
  }
}

resource "aws_lb_listener" "warehouse" {
  depends_on = [aws_acm_certificate_validation.warehouse]

  load_balancer_arn = aws_lb.warehouse.arn
  port              = 5439
  protocol          = "TCP"
  #  protocol          = "TLS"
  #  certificate_arn   = aws_acm_certificate.warehouse.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.warehouse.arn
  }
}
