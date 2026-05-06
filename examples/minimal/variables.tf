variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "subnet_ids" {
  description = "Subnet IDs for the FSx ONTAP file system (single subnet for SINGLE_AZ_1)"
  type        = list(string)
}
