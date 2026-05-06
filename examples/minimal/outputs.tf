output "file_system_id" {
  description = "ID of the FSx ONTAP file system"
  value       = module.fsx_ontap.file_system_id
}

output "file_system_dns_name" {
  description = "DNS name of the FSx ONTAP file system"
  value       = module.fsx_ontap.file_system_dns_name
}

output "file_system_owner_id" {
  description = "AWS account ID that owns the file system"
  value       = module.fsx_ontap.file_system_owner_id
}

output "file_system_vpc_id" {
  description = "VPC ID the file system resides in"
  value       = module.fsx_ontap.file_system_vpc_id
}

output "security_group_id" {
  description = "ID of the security group created for the file system"
  value       = module.fsx_ontap.security_group_id
}
