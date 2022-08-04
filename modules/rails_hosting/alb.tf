resource "aws_lb_target_group" "web" {
  name        = "${local.prefix}-web"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/check"
    interval            = 30
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "web" {
  name               = "${local.prefix}-web"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_public.id]
  subnets            = data.aws_subnets.public.ids

  access_logs {
    enabled = true
    bucket  = aws_s3_bucket.logs.bucket
  }
}

resource "aws_lb_listener" "web_https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.web.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"


  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
