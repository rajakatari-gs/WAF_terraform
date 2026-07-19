##############################################################
# modules/asg/main.tf
# Creates: Launch Template, Auto Scaling Group,
#          CPU-based target tracking scaling policy
##############################################################

# ── User Data — installs and starts nginx ────────────────────
locals {
  cw_log_group_access = "/nginx/${var.name_prefix}/access"
  cw_log_group_error  = "/nginx/${var.name_prefix}/error"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    yum update -y

    amazon-linux-extras enable nginx1
    yum install -y nginx amazon-cloudwatch-agent

    systemctl enable nginx
    systemctl start nginx

    echo "OK" > /usr/share/nginx/html/health

    # --- Replace with your real deploy logic ---
    # aws s3 cp s3://your-bucket/frontend/latest.tar.gz /tmp/
    # tar -xzf /tmp/latest.tar.gz -C /usr/share/nginx/html/
    # -------------------------------------------

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CWCONFIG
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/nginx/access.log",
                "log_group_name": "${local.cw_log_group_access}",
                "log_stream_name": "{instance_id}"
              },
              {
                "file_path": "/var/log/nginx/error.log",
                "log_group_name": "${local.cw_log_group_error}",
                "log_stream_name": "{instance_id}"
              }
            ]
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
      -s
  EOF
  )
}

# ── Launch Template ───────────────────────────────────────────
resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.instance_sg_id]
    delete_on_termination       = true
  }

  user_data = local.user_data

  key_name = var.key_name != "" ? var.key_name : null

  # Prefer spot for non-prod — override in tfvars if needed
  # instance_market_options {
  #   market_type = "spot"
  # }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 enforced
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.name_prefix}-instance" })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, { Name = "${var.name_prefix}-volume" })
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# ── Auto Scaling Group ────────────────────────────────────────
resource "aws_autoscaling_group" "this" {
  name                = "${var.name_prefix}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
  # ELB health check grace period — give nginx time to start
  health_check_grace_period = 120

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # Replace instances on launch template change
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Lifecycle hooks — drain connections before terminating
  initial_lifecycle_hook {
    name                 = "${var.name_prefix}-termination-hook"
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    heartbeat_timeout    = 60
    default_result       = "CONTINUE"
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name_prefix}-asg-instance" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# ── CPU Target Tracking Scaling Policy ───────────────────────
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.name_prefix}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value       = 60.0
    disable_scale_in   = false
  }
}

# ── ALB Request Count Scaling Policy ─────────────────────────
resource "aws_autoscaling_policy" "alb_requests" {
  name                   = "${var.name_prefix}-alb-request-scaling"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
    target_value     = 1000.0
    disable_scale_in = false
  }
}
