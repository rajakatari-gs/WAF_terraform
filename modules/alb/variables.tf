variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs. Leave empty to disable."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
