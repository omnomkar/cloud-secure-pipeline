variable "region" {
  description = "AWS region to create the state backend resources in"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally-unique name for the S3 bucket that will store Terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name for the DynamoDB table used for Terraform state locking"
  type        = string
  default     = "terraform-locks"
}
