project_name = "nginx-frontend"
environment  = "staging"
aws_region   = "us-east-1"

vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

ami_id               = "ami-0c02fb55956c7d316"
instance_type        = "t3.small"
asg_min_size         = 1
asg_max_size         = 3
asg_desired_capacity = 2

health_check_path = "/"
certificate_arn   = ""

tags = {
  Team      = "techops"
  ManagedBy = "terraform"
}
