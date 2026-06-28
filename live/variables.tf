variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to prefix and tag all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (NAT instance lives here)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (k3s EC2 instance lives here)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Single availability zone used for both subnets"
  type        = string
  default     = "us-east-1a"
}

variable "nat_instance_type" {
  description = "Instance type for the NAT instance"
  type        = string
  default     = "t3.nano"
}
