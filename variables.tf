variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  type    = string
  default = ""
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
