##############################################################
# modules/alb/main.tf
# Creates: Application Load Balancer, Target Group,
#          HTTP listener (redirects to HTTPS if cert provided),
#          HTTPS listener (optional)
##############################################################

# ── Application Load Balancer ─────────────────────────────────
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = "${var.name_prefix}-alb"
    enabled = var.access_logs_bucket != "" ? true : false
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })
}

# ── Target Group ──────────────────────────────────────────────
resource "aws_lb_target_group" "this" {
  name        = "${var.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── HTTP Listener ─────────────────────────────────────────────
# Redirects to HTTPS when a cert is provided, otherwise forwards directly
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }

  tags = var.tags
}

# ── HTTPS Listener (only when cert ARN is provided) ───────────
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = var.tags
}
