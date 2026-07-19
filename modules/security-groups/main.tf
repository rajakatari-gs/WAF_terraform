##############################################################
# modules/security-groups/main.tf
# Two SGs:
#   alb_sg  — accepts 80/443 from internet
#   instance_sg — accepts 80 only from ALB SG
##############################################################

# ── ALB Security Group ────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow HTTP/HTTPS from internet to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

# ── EC2 Instance Security Group ───────────────────────────────
resource "aws_security_group" "instance" {
  name        = "${var.name_prefix}-instance-sg"
  description = "Allow HTTP from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Uncomment to allow SSH from a bastion SG
  # ingress {
  #   description     = "SSH from bastion"
  #   from_port       = 22
  #   to_port         = 22
  #   protocol        = "tcp"
  #   security_groups = [var.bastion_sg_id]
  # }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-instance-sg" })
}
