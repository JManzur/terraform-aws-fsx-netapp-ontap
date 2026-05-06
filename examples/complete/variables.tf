variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "subnet_ids" {
  description = "Two subnet IDs in different AZs for MULTI_AZ_1 deployment"
  type        = list(string)
}

variable "route_table_ids" {
  description = "VPC route table IDs associated with the subnets"
  type        = list(string)
  default     = []
}

variable "fsx_admin_password" {
  description = "Admin password for the fsxadmin user"
  type        = string
  sensitive   = true
}

variable "svm_admin_password" {
  description = "Admin password for the SVM admin user"
  type        = string
  sensitive   = true
}
