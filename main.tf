##############################################################
# main.tf — root module
# Wires VPC → SGs → ALB → ASG together
##############################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# ── VPC ──────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.common_tags
}

# ── Security Groups ───────────────────────────────────────────
module "security_groups" {
  source = "./modules/security-groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  tags        = local.common_tags
}

# ── ALB ──────────────────────────────────────────────────────
module "alb" {
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  alb_sg_id          = module.security_groups.alb_sg_id
  health_check_path  = var.health_check_path
  certificate_arn    = var.certificate_arn
  tags               = local.common_tags
}

# ── IAM (instance profile for SSM access) ────────────────────
module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ── ASG ──────────────────────────────────────────────────────
module "asg" {
  source = "./modules/asg"

  name_prefix          = local.name_prefix
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  instance_sg_id       = module.security_groups.instance_sg_id
  instance_profile_name = module.iam.instance_profile_name
  private_subnet_ids   = module.vpc.private_subnet_ids
  target_group_arn     = module.alb.target_group_arn
  min_size             = var.asg_min_size
  max_size             = var.asg_max_size
  desired_capacity     = var.asg_desired_capacity
  tags                 = local.common_tags
}
