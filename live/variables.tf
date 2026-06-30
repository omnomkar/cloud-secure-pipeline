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

variable "k3s_instance_type" {
  description = "Instance type for the k3s node"
  type        = string
  default     = "t3.small"
}

variable "k3s_version" {
  description = "k3s version to install, pinned explicitly (never install \"latest\" on a box you can't reproduce)"
  type        = string
  default     = "v1.36.2+k3s1"
}

# No defaults on these two: they're specific to my fork of this repo, not
# generic enough to ship a sane default for.
variable "github_org" {
  description = "GitHub organization or username that owns the repo allowed to assume the CI/CD OIDC role"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix) allowed to assume the CI/CD OIDC role"
  type        = string
}

# No default, and marked sensitive so it never lands in plan/apply output -
# set this in your own gitignored terraform.tfvars, never commit a real value.
variable "app_secret_value" {
  description = "Runtime secret the Flask app reads from AWS Secrets Manager at startup"
  type        = string
  sensitive   = true
}
