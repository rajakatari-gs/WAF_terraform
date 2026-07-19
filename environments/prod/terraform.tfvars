project_name = "nginx-frontend"
environment  = "prod"
aws_region   = "us-east-1"

vpc_cidr             = "10.2.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24", "10.2.13.0/24"]

ami_id               = "ami-0c02fb55956c7d316"
instance_type        = "t3.medium"
asg_min_size         = 2
asg_max_size         = 6
asg_desired_capacity = 3

health_check_path = "/health"
certificate_arn   = ""

tags = {
  Team      = "techops"
  ManagedBy = "terraform"
}
