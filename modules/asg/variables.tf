variable "name_prefix" {
  type = string
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

variable "instance_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

variable "alb_resource_label" {
  description = "ALBTargetGroup resource label for request count scaling. Format: app/<alb-name>/<alb-id>/targetgroup/<tg-name>/<tg-id>"
  type        = string
  default     = ""
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 4
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
